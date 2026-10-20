//
//  PhoneFreeSharedSessionView.swift
//  Iphone app
//
//  The entire shared-session flow lives here: start, join, live, end.
//  A single sheet that swaps its content based on what the store tells it.

import SwiftUI

struct PhoneFreeSharedSessionView: View {
    @Environment(PhoneFreeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Set when the person picks "join" — the sheet shows the join screen
    /// and the link starts looking, until an offer or error arrives.
    @State private var wantsToJoin = false

    /// Derive the sheet's current screen from the store's live state.
    private var sheetState: SheetState {
        if let session = store.sharedSession {
            return session.isOver ? .ended : .inSession
        }
        if store.hasActiveSharedLink {
            if store.sharedCode != nil { return .hosting }
            if store.sharedJoinCode.count > 0 || !store.offeredSessions.isEmpty || wantsToJoin {
                return .joining
            }
            // Link exists but no code/offers yet — could be SharePlay starting
            return .hosting
        }
        if wantsToJoin { return .joining }
        return .idle
    }

    private enum SheetState {
        case idle, hosting, joining, inSession, ended
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    switch sheetState {
                    case .idle:
                        startJoinView
                    case .hosting:
                        hostingView
                    case .joining:
                        joiningView
                    case .inSession:
                        inSessionView
                    case .ended:
                        endedView
                    }
                }
                .padding(PhoneFreeTheme.screenPadding)
            }
            .background(PhoneFreeTheme.background)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        // Closing mid-join stops the search — the radio
                        // shouldn't keep listening after the person left.
                        if wantsToJoin, store.sharedSession == nil {
                            store.dismissSharedSession()
                            wantsToJoin = false
                        }
                        dismiss()
                    }
                    .foregroundStyle(PhoneFreeTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var navTitle: String {
        switch sheetState {
        case .idle: return "Shared Session"
        case .hosting: return "Your Session"
        case .joining: return "Join Session"
        case .inSession: return "Together"
        case .ended: return "Session Ended"
        }
    }

    private var startJoinView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Explain the two modes
            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Two ways to be together")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(
                        "Pick one before anyone joins. It says so right there, " +
                        "so nobody signs up by surprise."
                    )
                    .font(.footnote)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Mode picker
            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How this session works")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    ForEach(SharedSessionMode.allCases) { mode in
                        modeRow(mode)
                    }
                }
            }

            // Your name
            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your name in the room")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    TextField("Name", text: Bindable(store).participantName)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(PhoneFreeTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            // Transport choice
            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Start a session")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    // Nearby
                    transportRow(
                        title: "Invite code",
                        subtitle: "Two phones, same place — show a code, they type it",
                        symbol: "wifi",
                        action: { store.startSharedSession(mode: store.sharedSessionMode, nearby: true) }
                    )

                    Divider().background(PhoneFreeTheme.muted.opacity(0.3))

                    // SharePlay
                    transportRow(
                        title: "FaceTime (SharePlay)",
                        subtitle: "Both on a call — the session lives in the call",
                        symbol: "video.fill",
                        action: { store.startSharedSession(mode: store.sharedSessionMode, nearby: false) }
                    )
                }
            }

            // Join choice
            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Or join theirs")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    transportRow(
                        title: "Join a session",
                        subtitle: "They showed you a code — type it here",
                        symbol: "arrow.right.circle",
                        action: {
                            wantsToJoin = true
                            store.lookForSharedSessions(nearby: true)
                        }
                    )
                }
            }
        }
    }

    private var hostingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "qrcode")
                            .foregroundStyle(PhoneFreeTheme.accent)
                        Text("Show this code to the other person")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    if let code = store.sharedCode {
                        Text(code)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(PhoneFreeTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Text("They tap \"Invite code\" and type these four characters.")
                        .font(.caption)
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    // Mode reminder
                    if let room = store.sharedSession {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                            Text(room.mode.caption)
                        }
                        .font(.caption)
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Waiting indicator
            PhoneFreeCard {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(PhoneFreeTheme.accent)
                    Text("Waiting for them to join…")
                        .font(.subheadline)
                        .foregroundStyle(PhoneFreeTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            // Joined participants
            if let room = store.sharedSession, room.participants.count > 1 {
                PhoneFreeCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("In the room")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        ForEach(room.participants) { person in
                            participantRow(person, isHost: true)
                        }
                    }
                }
            }

            // Error
            if let error = store.sharedSessionError {
                PhoneFreeCard {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(PhoneFreeTheme.caution)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var joiningView: some View {
        VStack(alignment: .leading, spacing: 16) {
            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter the code they showed you")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    TextField("ABCD", text: Bindable(store).sharedJoinCode)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(PhoneFreeTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .textInputAutocapitalization(.characters)
                        .onChange(of: store.sharedJoinCode) { _, new in
                            store.sharedJoinCode = new.uppercased()
                                .filter { SharedSessionCode.alphabet.contains($0) }
                        }
                }
            }

            // Nearby hosts list
            if !store.offeredSessions.isEmpty {
                PhoneFreeCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or pick a nearby session")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        ForEach(store.offeredSessions) { offer in
                            Button {
                                store.joinSharedSession(offer, code: store.sharedJoinCode)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(offer.hostName)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.white)
                                        Text("\(offer.mode.label) · since \(offer.anchor, formatter: timeFormatter)")
                                            .font(.caption)
                                            .foregroundStyle(PhoneFreeTheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(PhoneFreeTheme.muted)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if let error = store.sharedSessionError {
                PhoneFreeCard {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(PhoneFreeTheme.caution)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // A join needs a discovered host to invite; the code alone can't
            // find one. The button says so plainly rather than sitting dead.
            Button {
                if let offer = store.offeredSessions.first {
                    store.joinSharedSession(offer, code: store.sharedJoinCode)
                }
            } label: {
                Text(store.offeredSessions.isEmpty
                     ? "Looking for their phone nearby…"
                     : "Join their session")
            }
            .disabled(store.offeredSessions.isEmpty || store.sharedJoinCode.count != 4)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(store.offeredSessions.isEmpty || store.sharedJoinCode.count != 4
                        ? PhoneFreeTheme.muted.opacity(0.3)
                        : PhoneFreeTheme.accent)
            .foregroundStyle(store.offeredSessions.isEmpty || store.sharedJoinCode.count != 4
                             ? PhoneFreeTheme.muted
                             : PhoneFreeTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .font(.subheadline.weight(.medium))
        }
    }

    @ViewBuilder private var inSessionView: some View {
        if let room = store.sharedSession {
            VStack(alignment: .leading, spacing: 16) {
            // Shared clock
            PhoneFreeCard {
                VStack(spacing: 8) {
                    Text("Together since")
                        .font(.caption)
                        .foregroundStyle(PhoneFreeTheme.muted)
                    Text(room.anchor, formatter: dateFormatter)
                        .font(.system(.title2, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(PhoneFreeFormat.duration(room.duration(at: Date())))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(PhoneFreeTheme.reward)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.5), value: room.duration(at: Date()))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            // Mode badge
            PhoneFreeCard {
                HStack {
                    Image(systemName: room.mode == .sharedFate ? "link" : "person.2")
                        .foregroundStyle(PhoneFreeTheme.accent)
                    Text(room.mode == .sharedFate
                        ? "Shared fate — one picks up, ends for both"
                        : "Own counters — your phone, your rules")
                        .font(.footnote)
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Participants
            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("In the room")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    ForEach(room.participants) { person in
                        participantRow(person, isHost: false)
                    }
                }
            }

            // End / Leave button
            Button(role: .destructive) {
                if room.mode == .sharedFate {
                    store.endSharedSession()
                } else {
                    store.leaveSharedSession()
                }
            } label: {
                HStack {
                    Image(systemName: room.mode == .sharedFate ? "xmark.circle" : "person.badge.minus")
                    Text(room.mode == .sharedFate ? "End for everyone" : "Leave session")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PhoneFreeTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .frame(minHeight: 48)
                .background(PhoneFreeTheme.caution)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            }
        }
    }

    @ViewBuilder private var endedView: some View {
        if let room = store.sharedSession {
            VStack(alignment: .leading, spacing: 16) {
                PhoneFreeCard {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(PhoneFreeTheme.reward)

                        Text(endHeadline(for: room))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("You were together for \(PhoneFreeFormat.duration(room.duration(at: room.endedAt ?? Date()))).")
                            .font(.subheadline)
                            .foregroundStyle(PhoneFreeTheme.muted)
                            .multilineTextAlignment(.center)

                        if let reason = room.endReason {
                            Text(endReasonText(reason))
                                .font(.footnote)
                                .foregroundStyle(PhoneFreeTheme.muted)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                Button("Done") {
                    store.dismissSharedSession()
                    dismiss()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PhoneFreeTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .frame(minHeight: 48)
                .background(PhoneFreeTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: - Helpers

    private func modeRow(_ mode: SharedSessionMode) -> some View {
        let isSelected = store.sharedSessionMode == mode

        return Button {
            store.play(.selection)
            store.sharedSessionMode = mode
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mode.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? PhoneFreeTheme.accent : PhoneFreeTheme.muted.opacity(0.5))
                }
                Text(mode.caption)
                    .font(.caption)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func transportRow(title: String, subtitle: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.callout)
                    .foregroundStyle(PhoneFreeTheme.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(PhoneFreeTheme.muted)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func participantRow(_ person: SharedParticipant, isHost: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(person.isOnPhone ? PhoneFreeTheme.caution : PhoneFreeTheme.reward)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text(person.name + (person.id == store.participantID ? " (you)" : ""))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text(person.isOnPhone ? "On phone" : "Phone free")
                    .font(.caption)
                    .foregroundStyle(person.isOnPhone ? PhoneFreeTheme.caution : PhoneFreeTheme.reward)
            }

            Spacer()

            if person.id != store.participantID, let room = store.sharedSession, !room.isOver {
                Text(person.isOnPhone ? "📱" : "📵")
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }

    private func endHeadline(for room: SharedSessionState) -> String {
        switch room.endReason {
        case .byChoice: return "Ended together"
        case .brokenBy(_, let name): return "\(name) picked up — the stretch ended"
        case .disbanded(let name): return "\(name) left — the session ended"
        case .none: return "Session ended"
        }
    }

    private func endReasonText(_ reason: SharedSessionEnd) -> String {
        switch reason {
        case .byChoice: return "You chose to end it. Nothing lost — the next one starts when you start it."
        case .brokenBy(_, let name): return "\(name) picked up their phone past the grace period. Ending early isn't failing — it's just ending."
        case .disbanded(let name): return "\(name) left the session. The room closed — no blame, just done."
        }
    }
}

// No store extension needed — the view computes its state from the store's
// actual published properties.