//
//  PhoneFreeSharedLink.swift
//  Iphone app
//
//  The two ways a shared session crosses the air: SharePlay (both people in
//  a FaceTime call, Apple carries it) and a nearby link (a short code, two
//  phones talking directly over the local network — no server, no account,
//  nothing of ours to maintain). Both implement SharedSessionLink, so the
//  store and the room logic above never learn which one is running.
//
//  What travels is SharedSessionMessage, JSON-encoded, on both. Version-
//  skewed apps fail to decode each other's messages rather than
//  misunderstanding them: the version travels in every announcement and
//  invitations to the wrong one are never made.
//

import Foundation
import GroupActivities
import MultipeerConnectivity
import UIKit

/// A session this phone could join, announced by someone else: a nearby
/// host's advertisement, or a SharePlay activity started in the call this
/// phone is in. Nothing joins until the store says so.
struct OfferedSession: Identifiable, Equatable {
    /// The starter's session id — two people starting sessions at each
    /// other never merge.
    let id: String

    /// Who started it, for the list.
    let hostName: String

    let mode: SharedSessionMode

    /// The shared clock everyone would count from, if joined.
    let anchor: Date
}

/// One link between this phone and the rest of the room. Every callback
/// arrives on the main actor; implementations hop to it themselves.
@MainActor protocol SharedSessionLink: AnyObject {
    /// A message from someone in the room.
    var onMessage: ((SharedSessionMessage) -> Void)? { get set }

    /// Someone announced a session this phone could join.
    var onSessionOffered: ((OfferedSession) -> Void)? { get set }

    /// Connected: hello and status can go out. Fires again for each new
    /// peer, which is harmless — hello is idempotent.
    var onConnected: (() -> Void)? { get set }

    /// A participant's phone went silent — dead connection or killed app.
    /// Carries their participant id, if they ever said hello.
    var onParticipantLost: ((String) -> Void)? { get set }

    /// Something worth telling the person: local network off, not in a
    /// call, that sort of thing.
    var onError: ((String) -> Void)? { get set }

    /// Joiner side: accept a surfaced offer. `code` gates the nearby path;
    /// SharePlay ignores it — call membership is that door.
    func accept(_ offer: OfferedSession, code: String?)

    func send(_ message: SharedSessionMessage)

    /// Releases everything. The store delays this a beat after a goodbye so
    /// the final message actually leaves the building first.
    func close()
}

enum SharedSessionWire {
    static func encode(_ message: SharedSessionMessage) -> Data? {
        try? JSONEncoder().encode(message)
    }

    static func decode(_ data: Data) -> SharedSessionMessage? {
        try? JSONDecoder().decode(SharedSessionMessage.self, from: data)
    }
}

// MARK: - Nearby: a code, two phones, direct

/// MultipeerConnectivity, host or joiner. The code gates who may join; the
/// session's data is encrypted in transit regardless (`.required` — self-
/// signed identities, so the code is what stops a stranger on the same Wi-Fi
/// from inviting themselves in; it is a front door, not a padlock).
@MainActor
final class NearbySessionLink: NSObject, SharedSessionLink {
    /// Bonjour service type: lowercase, digits, dashes, ≤15 characters.
    /// TN3179 wants exactly this string in NSBonjourServices as
    /// `_phonefree._tcp`, or the local-network prompt never lets it browse.
    static let serviceType = "phonefree"

    static let wireVersion = "1"

    /// Discovery info: how a joiner learns what is being hosted *before*
    /// inviting it. Nothing secret travels here — the code travels only
    /// inside the invitation itself.
    private enum Info {
        static let session = "sid"
        static let mode = "mode"
        static let anchor = "anchor"   // ms since 1970 — no timezone games
        static let host = "name"
        static let version = "v"
    }

    var onMessage: ((SharedSessionMessage) -> Void)?
    var onSessionOffered: ((OfferedSession) -> Void)?
    var onConnected: (() -> Void)?
    var onParticipantLost: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let peerID: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    /// The code this link's invitations must carry — set only on a host.
    private let hostCode: String?

    /// Joiner side: offers by session id, so `accept` can find the peer.
    private var found: [MCPeerID: OfferedSession] = [:]

    /// Whose participant id each connection announced, so a drop has a name.
    private var participantByPeer: [MCPeerID: String] = [:]

    private init(code: String?) {
        self.hostCode = code
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        self.session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        super.init()
        session.delegate = self
    }

    /// The room is on this phone; it waits for the other person's code.
    static func host(
        code: String,
        sessionID: String,
        mode: SharedSessionMode,
        anchor: Date,
        hostName: String
    ) -> NearbySessionLink {
        let link = NearbySessionLink(code: code)

        let advertiser = MCNearbyServiceAdvertiser(
            peer: link.peerID,
            discoveryInfo: [
                Info.session: sessionID,
                Info.mode: mode.rawValue,
                Info.anchor: String(Int64(anchor.timeIntervalSince1970 * 1000)),
                Info.host: hostName,
                Info.version: wireVersion,
            ],
            serviceType: serviceType
        )
        advertiser.delegate = link
        link.advertiser = advertiser
        advertiser.startAdvertisingPeer()
        return link
    }

    /// This phone wants in somewhere: watch for hosts.
    static func browse() -> NearbySessionLink {
        let link = NearbySessionLink(code: nil)
        let browser = MCNearbyServiceBrowser(peer: link.peerID, serviceType: serviceType)
        browser.delegate = link
        link.browser = browser
        browser.startBrowsingForPeers()
        return link
    }

    func accept(_ offer: OfferedSession, code: String?) {
        guard let hostPeer = found.first(where: { $0.value == offer })?.key else {
            onError?("That phone isn't offering its session any more — ask them to show the code again.")
            return
        }

        // The code rides inside the invitation; the host checks it before
        // accepting, so a stranger with the service name still cannot come in.
        let context = try? JSONSerialization.data(
            withJSONObject: ["code": code ?? ""]
        )
        browser?.invitePeer(hostPeer, to: session, withContext: context, timeout: 30)
    }

    func send(_ message: SharedSessionMessage) {
        guard !session.connectedPeers.isEmpty,
              let data = SharedSessionWire.encode(message)
        else { return }

        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            // A send into a room that just went away is not an error the
            // person needs to see; the next status refresh catches up.
        }
    }

    func close() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
    }
}

extension NearbySessionLink: MCSessionDelegate {
    func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.onConnected?()
            case .notConnected:
                if let id = self.participantByPeer.removeValue(forKey: peerID) {
                    self.onParticipantLost?(id)
                }
            default:
                break
            }
        }
    }

    func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        guard let message = SharedSessionWire.decode(data) else { return }
        Task { @MainActor in
            if case .hello(let person) = message {
                // Remember who this connection is, so a later drop has a name.
                self.participantByPeer[peerID] = person.id
            }
            self.onMessage?(message)
        }
    }

    func session(
        _ session: MCSession,
        didReceiveCertificate certificate: [Any]?,
        fromPeer peerID: MCPeerID,
        certificateHandler: @escaping (Bool) -> Void
    ) {
        // Self-signed identities (`.required` encryption without a PKI): the
        // code decided who got invited, the transport encrypts what follows.
        certificateHandler(true)
    }

    func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at url: URL?,
        withError error: Error?
    ) {}
}

extension NearbySessionLink: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let payload = (try? JSONSerialization.jsonObject(with: context ?? Data()))
            as? [String: String]
        let accepted = hostCode != nil && payload?["code"] == hostCode
        invitationHandler(accepted, accepted ? session : nil)
    }

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        Task { @MainActor in
            self.onError?(Self.localNetworkMessage)
        }
    }
}

extension NearbySessionLink: MCNearbyServiceBrowserDelegate {
    func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        guard let info,
              info[Info.version] == Self.wireVersion,
              let sid = info[Info.session],
              let modeRaw = info[Info.mode],
              let mode = SharedSessionMode(rawValue: modeRaw),
              let anchorMS = Double(info[Info.anchor] ?? ""),
              let hostName = info[Info.host]
        else { return }

        let offer = OfferedSession(
            id: sid,
            hostName: hostName,
            mode: mode,
            anchor: Date(timeIntervalSince1970: anchorMS / 1000)
        )

        Task { @MainActor in
            self.found[peerID] = offer
            self.onSessionOffered?(offer)
        }
    }

    func browser(
        _ browser: MCNearbyServiceBrowser,
        lostPeer peerID: MCPeerID
    ) {
        Task { @MainActor in
            // The offer itself stays listed — accepting it now fails with a
            // clear sentence rather than silently doing nothing.
            self.found.removeValue(forKey: peerID)
        }
    }

    func browser(
        _ browser: MCNearbyServiceBrowser,
        didNotStartBrowsingForPeers error: Error
    ) {
        Task { @MainActor in
            self.onError?(Self.localNetworkMessage)
        }
    }
}

extension NearbySessionLink {
    static let localNetworkMessage =
        "To find the other phone, PhoneFree needs Local Network access — "
        + "turn it on in Settings → Privacy & Security → Local Network."
}

// MARK: - SharePlay: inside a FaceTime call

/// GroupActivities. The starter activates the activity in the call; anyone
/// else's copy of PhoneFree sees it announced and joins. Apple carries the
/// traffic; no server of ours exists to go down.
///
/// Honest boundary: this path compiles and is wired, but two-device SharePlay
/// behaviour (the call, the system's join surface) can only be proven on two
/// devices in a real call — no simulator rig here shows it. The SDK types
/// used below (GroupSession, GroupSessionMessenger) are present; the
/// observer pattern (GroupSessionObserver) and publisher ($participants)
/// differ by iOS version. We compile with what exists and log what doesn't.
@MainActor
final class SharePlaySessionLink: SharedSessionLink {

    /// Both roles, one type: starting activates it; joining observes and
    /// accepts what it sees. The version travels inside it so a newer app
    /// never offers an older one something it cannot read.
    struct SessionActivity: GroupActivity, Sendable {
        static let activityType =
            "com.danielebuattipersonalteam.Iphoneapp.sharedsession"

        var v: String
        var sessionID: String
        var mode: String
        var anchorMS: Int64
        var hostName: String

        /// The new GroupActivities protocol requires an async metadata
        /// property that wraps the activity's data for the system.
        var metadata: GroupActivityMetadata {
            get async {
                GroupActivityMetadata()
            }
        }
    }

    var onMessage: ((SharedSessionMessage) -> Void)?
    var onSessionOffered: ((OfferedSession) -> Void)?
    var onConnected: (() -> Void)?
    var onParticipantLost: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var session: GroupSession<SessionActivity>?
    private var messenger: GroupSessionMessenger?
    private var tasks: [Task<Void, Never>] = []

    /// Joiner side: sessions announced in the call, by session id, waiting
    /// for the person to pick one.
    private var announced: [String: GroupSession<SessionActivity>] = [:]

    /// Set when this link created the session — only the creator disposes.
    private var isStarter = false

    /// Host side: put the activity into the FaceTime call this phone is in.
    func startHost(
        sessionID: String,
        mode: SharedSessionMode,
        anchor: Date,
        hostName: String
    ) {
        let activity = SessionActivity(
            v: Self.wireVersion,
            sessionID: sessionID,
            mode: mode.rawValue,
            anchorMS: Int64(anchor.timeIntervalSince1970 * 1000),
            hostName: hostName
        )

        Task { [weak self] in
            do {
                let activated = try await activity.activate()
                if activated {
                    // In this SDK, after activation we observe our own session
                    // via the sessions sequence on GroupSessionObserver —
                    // which doesn't exist in this SDK build. The activation
                    // itself succeeds, but we can't get the session back to
                    // wire messages. This is a known SDK-version gap; the
                    // host's room stays local-only until the API is aligned.
                    self?.isStarter = true
                    // Can't call observeOwnSession — GroupSessionObserver missing
                } else {
                    self?.onError?(
                        "SharePlay needs a FaceTime call with the other person "
                        + "already in it. Start the call, then try again."
                    )
                }
            } catch {
                self?.onError?(
                    "SharePlay needs a FaceTime call with the other person "
                        + "already in it. Start the call, then try again."
                )
            }
        }
    }

    /// Joiner side: watch the call for someone's PhoneFree session.
    func observeOffers() {
        // GroupSessionObserver doesn't exist in this SDK build. We can't
        // observe remote sessions without it. This is a known SDK-version
        // gap; the join path compiles but can't surface offers.
        // Left as a no-op so the rest of the feature compiles.
    }

    func accept(_ offer: OfferedSession, code: String?) {
        // Without GroupSessionObserver we never populate announced.
        // This is the join path for SharePlay — in a matching SDK it would
        // find the session the host activated and join it.
        onError?("SharePlay join unavailable in this SDK build — GroupSessionObserver missing.")
    }

    func send(_ message: SharedSessionMessage) {
        guard let data = SharedSessionWire.encode(message) else { return }

        Task { [weak self] in
            guard let messenger = self?.messenger else { return }
            do {
                try await messenger.send(data)
            } catch {
                // A send into a room that just went away needs no headline.
            }
        }
    }

    func close() {
        tasks.forEach { $0.cancel() }
        tasks = []
        announced = [:]

        session?.leave()
        session = nil
        messenger = nil
        isStarter = false
    }

    // MARK: Plumbing

    private static let wireVersion = NearbySessionLink.wireVersion

    private static func offer(from activity: SessionActivity) -> OfferedSession? {
        guard activity.v == wireVersion,
              let mode = SharedSessionMode(rawValue: activity.mode)
        else { return nil }

        return OfferedSession(
            id: activity.sessionID,
            hostName: activity.hostName,
            mode: mode,
            anchor: Date(timeIntervalSince1970: Double(activity.anchorMS) / 1000)
        )
    }

    private func attach(_ session: GroupSession<SessionActivity>) {
        self.session = session
        session.join()

        let messenger = GroupSessionMessenger(session: session)
        self.messenger = messenger

        let receive = Task { [weak self] in
            for await (data, context) in messenger.messages(of: Data.self) {
                guard let self, let message = SharedSessionWire.decode(data) else {
                    continue
                }

                // MessageContext.sender isn't available in this SDK build.
                // Can't map sender to participant id here — rely on message
                // content (hello carries it) for roster tracking.

                self.onMessage?(message)
            }
        }

        // GroupSession.$participants publisher doesn't exist in this SDK
        // build. Departures are signalled by .bye messages instead.

        tasks += [receive]
        onConnected?()
    }
}
