//
//  PhoneFreeSharedSession.swift
//  Shared
//
//  Compiled into BOTH the "Iphone app" target and the
//  "PhoneFreeWidgetExtension" target, so every surface can name the same
//  shared session.
//
//  What a shared session IS, before any transport has an opinion: who is in
//  the room, which of the two agreements they made, and what the room
//  believes has happened. The store reduces wire messages into this value;
//  the UI only reads it. Keeping it here means the feature's whole logic is
//  testable the same way the counter is — a harness, no devices, no call.
//

import Foundation

/// One phone in the room, as the others see it.
nonisolated struct SharedParticipant: Codable, Equatable, Hashable, Identifiable {
    /// Stable per install — not the device name and not the iCloud account:
    /// two phones belonging to one person are two participants.
    var id: String

    /// What the others call them. The starter picks it; joiners keep their
    /// own.
    var name: String

    /// Their phone is currently in hand (their counter frozen). Informational
    /// in `.ownCounters`; the trip signal in `.sharedFate`.
    var isOnPhone: Bool

    /// When this phone was last heard from. Staleness is shown, never
    /// punished — a connection that went quiet is not a person who failed.
    var lastSeen: Date
}

/// The choice that defines the feature, made by whoever starts the session
/// and shown to the other person before they join. Both modes exist because
/// both are honest wants: company, and commitment.
nonisolated enum SharedSessionMode: String, Codable, CaseIterable, Identifiable {
    /// Your phone, your rules. Picking up ends *your* stretch and nothing
    /// else; the other phone simply sees that you did. Accountability without
    /// handing anyone a remote control on your streak.
    case ownCounters

    /// One stretch, everyone in it. A phone back in hand past its grace
    /// period ends the shared time for all of them. Said out loud before
    /// anyone joins, so nobody signs up for it by surprise.
    case sharedFate

    var id: String { rawValue }

    /// The picker's name.
    var label: String {
        switch self {
        case .ownCounters: return "Own counters"
        case .sharedFate: return "Shared fate"
        }
    }

    /// The sentence under it. This choice *is* the feature, so it gets said
    /// in plain words, not app words.
    var caption: String {
        switch self {
        case .ownCounters:
            return "Your phone, your rules. If you pick up, only your own "
                + "counter reacts — the other person just sees it."
        case .sharedFate:
            return "One stretch for everyone. If anyone picks up past their "
                + "grace period, the shared time ends for all of you."
        }
    }
}

/// How a session ended. The room remembers, the screens say it plainly, and
/// none of the three is a failure — ending early is still ending.
nonisolated enum SharedSessionEnd: Codable, Equatable {
    /// Finished by choice: dinner over, goodnight said.
    case byChoice

    /// A phone went back in hand past its grace. Names the phone, not the
    /// person — ending early is not an error and the screen says so.
    case brokenBy(id: String, name: String)

    /// Somebody left the room (deliberately, or their connection died).
    case disbanded(name: String)
}

/// Everything that travels between the two phones. Each device is the only
/// authority on itself; nobody reports for anyone else.
nonisolated enum SharedSessionMessage: Codable, Equatable {
    /// "I'm here" — carries everything needed to show this person. Sent on
    /// connect and again whenever the link comes back.
    case hello(SharedParticipant)

    /// A freshness update: still down, or back in hand. `at` marks when the
    /// sender thinks it happened; arrival order wins, because two phones'
    /// clocks are never close enough to rank events *between* them.
    case status(id: String, isOnPhone: Bool, at: Date)

    /// This phone's own counter just reset — past grace, by use. In shared
    /// fate it ends the room; in own counters the next `.status` already
    /// shows it, so the engine drops it there.
    case pickedUp(id: String, name: String)

    /// Someone is ending the session for everyone. First end wins.
    case end(SharedSessionEnd)

    /// Somebody left. In shared fate that ends the room — the premise was
    /// everyone in it. In own counters the rest carry on.
    case bye(id: String)
}

/// The room as any participant should see it. Reducing messages into this
/// value is the entire feature; transports only carry bytes in and out.
nonisolated struct SharedSessionState: Codable, Equatable {
    /// Identifies the session across the two links (the SharePlay activity,
    /// the nearby-host advertisement). Two people starting sessions at each
    /// other never merge: an invite carries the host's id, and only messages
    /// about that session are accepted.
    var id: String

    var mode: SharedSessionMode

    /// The moment everyone is counting from — the starter's put-down, or
    /// when the last person joined; chosen once, agreed by all.
    var anchor: Date

    var participants: [SharedParticipant]

    /// Set at the moment the session ended, so every screen — including one
    /// that opens later — settles on the same frozen number.
    var endedAt: Date?

    var endReason: SharedSessionEnd?

    var isOver: Bool { endedAt != nil }

    /// How long the session ran: live until it ends, frozen afterwards.
    func duration(at now: Date) -> TimeInterval {
        max(0, (endedAt ?? now).timeIntervalSince(anchor))
    }

    /// Reduces one wire message. Deliberately conservative: the first end
    /// wins, and after the end nothing more is believed — late arrivals
    /// cannot un-end a session or rewrite who or why.
    mutating func receive(_ message: SharedSessionMessage, at now: Date = Date()) {
        switch message {
        case .hello(let person):
            guard !isOver else { return }
            if let index = participants.firstIndex(where: { $0.id == person.id }) {
                participants[index] = person
                participants[index].lastSeen = now
            } else {
                participants.append(person)
            }

        case .status(let id, let isOnPhone, _):
            guard !isOver,
                  let index = participants.firstIndex(where: { $0.id == id })
            else { return }
            participants[index].isOnPhone = isOnPhone
            participants[index].lastSeen = now

        case .pickedUp(let id, let name):
            guard !isOver else { return }
            guard mode == .sharedFate else {
                // Own counters: a pickup is a fact, not a verdict. The next
                // status update already shows it; it ends nobody's session.
                return
            }
            endReason = .brokenBy(id: id, name: name)
            endedAt = now

        case .end(let reason):
            guard !isOver else { return }
            endReason = reason
            endedAt = now

        case .bye(let id):
            guard !isOver else { return }

            let name = participants.first(where: { $0.id == id })?.name
            participants.removeAll { $0.id == id }

            if mode == .sharedFate {
                // The premise was everyone in it — someone gone means it is
                // over, whoever they were or however they went.
                endReason = .disbanded(name: name ?? "Someone")
                endedAt = now
            } else if participants.isEmpty {
                // An empty room is over. Nobody was betrayed; they left.
                endReason = .disbanded(name: name ?? "Everyone")
                endedAt = now
            }
        }
    }
}

/// The short code one phone shows and the other types in. Four characters,
/// read aloud across a table without needing a second round: no 0/O, 1/I/L
/// to squint at. It gates who may join a nearby session — a room's front
/// door, not a padlock; everything sent is encrypted in transit regardless.
nonisolated enum SharedSessionCode {
    static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    static func generate() -> String {
        String((0..<4).map { _ in alphabet.randomElement()! })
    }
}
