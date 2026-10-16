//
//  PhoneFreeLearnView.swift
//  Iphone app
//
//  The reading side of the app: what is actually going on when a phone pulls
//  at you, what to do with the time instead, and how to turn any of it into
//  something that helps another person.
//
//  Written in short chunks on purpose. Long walls of text are the thing that
//  makes people put the app down — especially the people this app is for.
//

import SwiftUI

// MARK: - Topic model

struct PhoneFreeLearnTopic: Identifiable, Hashable {
    let id: String
    let section: String
    let title: String
    let subtitle: String
    let symbol: String
    let body: [PhoneFreeLearnBlock]
}

enum PhoneFreeLearnBlock: Hashable {
    case paragraph(String)
    case heading(String)
    case bullets([String])
    case note(String)
}

// MARK: - Library

enum PhoneFreeLearnLibrary {
    static let topics: [PhoneFreeLearnTopic] = [
        PhoneFreeLearnTopic(
            id: "loop",
            section: "Understanding it",
            title: "Why it's hard to put down",
            subtitle: "The pull is designed, not a personal failing.",
            symbol: "arrow.triangle.2.circlepath",
            body: [
                .paragraph(
                    "Almost nothing about a phone is neutral. The feed, the "
                    + "notifications, the pull-to-refresh: each one is built to "
                    + "make you check again."
                ),
                .heading("The slot machine effect"),
                .paragraph(
                    "Sometimes checking pays off and sometimes it doesn't — and "
                    + "not knowing which is what keeps a behaviour going. It is "
                    + "the same mechanic as a slot machine, and it works on "
                    + "everyone."
                ),
                .heading("The urge is shorter than it feels"),
                .paragraph(
                    "An urge arrives, peaks, and fades. It is usually minutes, "
                    + "not hours. Most of the time you are waiting out a wave, "
                    + "not fighting a permanent need."
                ),
                .bullets([
                    "Notice the urge and name it: \"this is the pull\".",
                    "Do something with your hands for two minutes.",
                    "The wave drops. It always does."
                ]),
                .note(
                    "That is also why the app's gate asks rather than blocks. "
                    + "Two minutes of friction is enough for the wave to pass."
                )
            ]
        ),
        PhoneFreeLearnTopic(
            id: "residue",
            section: "Understanding it",
            title: "Where the day goes",
            subtitle: "Small checks cost more than the seconds they take.",
            symbol: "hourglass.bottomhalf.filled",
            body: [
                .paragraph(
                    "Picking up a phone for ten seconds is not really ten "
                    + "seconds. After you put it down, part of your attention "
                    + "stays behind — researchers call it attention residue. "
                    + "You get back to what you were doing slower, and a bit "
                    + "worse."
                ),
                .paragraph(
                    "Ten checks a day is not ten interruptions. It is a day "
                    + "that never quite gets going."
                ),
                .heading("A useful experiment"),
                .paragraph(
                    "Leave the phone in another room for one stretch today. "
                    + "Not because it is virtuous, but so you can compare. The "
                    + "difference is usually obvious."
                )
            ]
        ),
        PhoneFreeLearnTopic(
            id: "notime",
            section: "Understanding it",
            title: "Why time limits alone don't hold",
            subtitle: "Subtraction fails without substitution.",
            symbol: "arrow.uturn.backward",
            body: [
                .paragraph(
                    "Telling yourself \"less phone\" leaves a gap. The gap is "
                    + "what gets filled — usually by the phone."
                ),
                .heading("Add something, don't just subtract"),
                .paragraph(
                    "A phone-free stretch works best when it has a job: "
                    + "reading, a walk, cooking, stretching, a phone call. "
                    + "That is what the plan builder on the Away tab is for."
                ),
                .bullets([
                    "Pick one thing, not five.",
                    "Make it easy to start — book open, shoes by the door.",
                    "Short and finished beats long and abandoned."
                ])
            ]
        ),
        PhoneFreeLearnTopic(
            id: "ocdadhd",
            section: "Getting through it",
            title: "If your brain is the OCD or ADHD kind",
            subtitle: "Some tactics help. Some quietly make it worse.",
            symbol: "brain.head.profile",
            body: [
                .heading("On ADHD"),
                .paragraph(
                    "Friction that lands on the *good* action is the enemy. If "
                    + "starting a phone-free stretch takes four taps and a "
                    + "decision, it will not happen. That is why the app keeps "
                    + "starting a goal to one button, and why the duration is a "
                    + "row of plain numbers."
                ),
                .paragraph(
                    "Immediate feedback matters too. Seeing the counter move "
                    + "gives the brain something to hold on to while the "
                    + "reward is still far away."
                ),
                .heading("On OCD"),
                .paragraph(
                    "Streaks are a genuine risk here. A streak can turn into "
                    + "a rule you feel you must not break, and a broken streak "
                    + "into a spiral. So this app never punishes a break: no "
                    + "red marks, no \"you lost it\", no reminders about what "
                    + "you failed to do."
                ),
                .paragraph(
                    "If you notice yourself checking the numbers to feel okay, "
                    + "treat that as the signal it is, and give the numbers a "
                    + "rest. The app will still be here."
                ),
                .note(
                    "This app is a habit tool, not treatment. If phone use is "
                    + "tangled up with anxiety or compulsions, a clinician who "
                    + "knows OCD and ADHD will help far more than any app."
                )
            ]
        ),
        PhoneFreeLearnTopic(
            id: "urges",
            section: "Getting through it",
            title: "Three moves for the moment",
            subtitle: "For when you've already picked it up.",
            symbol: "hand.raised.fill",
            body: [
                .heading("1. Name it"),
                .paragraph(
                    "\"I'm reaching for it because I'm bored\" lands very "
                    + "differently from a vague pull you can't see."
                ),
                .heading("2. Delay, don't deny"),
                .paragraph(
                    "Tell yourself: not never, just in ten minutes. Refusal "
                    + "creates tension; delay mostly creates forgetting."
                ),
                .heading("3. Move the phone, not yourself"),
                .paragraph(
                    "Standing up and putting it on a shelf breaks the loop "
                    + "better than willpower does, because your hands did "
                    + "something."
                )
            ]
        ),
        PhoneFreeLearnTopic(
            id: "five",
            section: "Getting through it",
            title: "If five minutes is all you have",
            subtitle: "Small and repeatable beats big and rare.",
            symbol: "timer",
            body: [
                .paragraph(
                    "You do not need an hour. Five minutes, twice, is a real "
                    + "change and it is the version you will actually repeat."
                ),
                .bullets([
                    "Make a drink without the phone in the room.",
                    "Step outside and look at something far away.",
                    "Stretch whatever is tight.",
                    "Write down the one thing you keep meaning to do."
                ])
            ]
        ),
        PhoneFreeLearnTopic(
            id: "others",
            section: "Helping others",
            title: "Turn the time into something for someone else",
            subtitle: "The fastest way to make a pause feel worth it.",
            symbol: "person.2.fill",
            body: [
                .paragraph(
                    "Phone-free time gets easier when it is aimed outward. "
                    + "Almost everything here can be done with or for another "
                    + "person, and the pull weakens when someone is expecting "
                    + "you."
                ),
                .bullets([
                    "Call someone you have been meaning to call. Not a text.",
                    "Write a real message to a friend who is having a hard week.",
                    "Ask a neighbour if they need anything while you're out.",
                    "Cook something for someone, or bring them half.",
                    "Offer an hour of your skills to a local group or charity.",
                    "Sit with someone who is lonely. No phone on the table."
                ]),
                .note(
                    "Telling one person you're doing this makes it real. "
                    + "Accountability beats willpower."
                )
            ]
        ),
        PhoneFreeLearnTopic(
            id: "model",
            section: "Helping others",
            title: "Do it out loud",
            subtitle: "Being watched is the strongest version of this.",
            symbol: "eye.fill",
            body: [
                .paragraph(
                    "People copy what they see, especially children and the "
                    + "people you live with. A phone that stays in a pocket at "
                    + "the table teaches more than any rule about it."
                ),
                .bullets([
                    "Say why you're putting it down, out loud.",
                    "Keep phones away from meals and out of the bedroom.",
                    "Agree one shared phone-free window with whoever you live with.",
                    "Ask someone to hold you to it, and tell them when you manage it."
                ])
            ]
        ),
        PhoneFreeLearnTopic(
            id: "help",
            section: "If it feels bigger",
            title: "When it's more than a habit",
            subtitle: "Real help, real people.",
            symbol: "heart.text.square",
            body: [
                .paragraph(
                    "If phone or internet use is affecting your sleep, your "
                    + "work, your mood, or your relationships, that is worth "
                    + "taking to a professional — not because you've failed, "
                    + "but because it's easier with help."
                ),
                .bullets([
                    "Start with your family doctor or GP.",
                    "If you have a therapist or psychiatrist, tell them about "
                    + "the screen time specifically.",
                    "For OCD or ADHD, a clinician who treats those directly "
                    + "will get you further than general advice.",
                    "Tell one person you trust what you're working on."
                ]),
                .note(
                    "This app can't diagnose anything and isn't a substitute "
                    + "for care. It's a timer, a bit of friction, and some "
                    + "company."
                )
            ]
        )
    ]

    static var sections: [String] {
        var seen: [String] = []

        for topic in topics where !seen.contains(topic.section) {
            seen.append(topic.section)
        }

        return seen
    }
}

// MARK: - Screen

struct PhoneFreeLearnView: View {
    @Environment(PhoneFreeStore.self) private var store

    @State private var addedActivity: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    ideaSection

                    ForEach(PhoneFreeLearnLibrary.sections, id: \.self) { section in
                        sectionView(section)
                    }

                    footerNote
                }
                .padding(.horizontal, PhoneFreeTheme.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(PhoneFreeTheme.background)
            .navigationDestination(for: PhoneFreeLearnTopic.self) { topic in
                PhoneFreeLearnDetail(topic: topic)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LEARN")
                .font(.system(size: 12, weight: .bold))
                .tracking(3)
                .foregroundStyle(PhoneFreeTheme.accent)

            Text("What's going on, and what to do")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Things to do

    private var ideaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel("THINGS TO DO INSTEAD")

            Text("Tap one to drop it into your plan. You'll find it on the "
                 + "Away tab.")
                .font(.system(size: 13))
                .foregroundStyle(PhoneFreeTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(PhoneFreeActivityLibrary.all) { activity in
                    activityRow(activity)
                }
            }

            if let addedActivity {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(PhoneFreeTheme.accent)

                    Text("Added \(addedActivity) to your plan.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                }
                .transition(.opacity)
            }
        }
    }

    private func activityRow(_ activity: PhoneFreeActivity) -> some View {
        PhoneFreeCard {
            HStack(spacing: 14) {
                Image(systemName: activity.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(PhoneFreeTheme.background)
                    .frame(width: 38, height: 38)
                    .background(PhoneFreeTheme.accent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)

                    Text(activity.tagline)
                        .font(.system(size: 12))
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button {
                    store.plan.append(
                        PlannedActivity(
                            activityID: activity.id,
                            minutes: activity.defaultMinutes
                        )
                    )
                    store.save()

                    withAnimation {
                        addedActivity = activity.name
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PhoneFreeTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(activity.name) to your plan")
            }
        }
    }

    // MARK: - Topics

    private func sectionView(_ section: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel(section.uppercased())

            VStack(spacing: 10) {
                ForEach(
                    PhoneFreeLearnLibrary.topics.filter {
                        $0.section == section
                    }
                ) { topic in
                    NavigationLink(value: topic) {
                        topicCard(topic)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func topicCard(_ topic: PhoneFreeLearnTopic) -> some View {
        PhoneFreeCard {
            HStack(spacing: 14) {
                Image(systemName: topic.symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(PhoneFreeTheme.accent)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    Text(topic.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PhoneFreeTheme.muted)
            }
        }
    }

    private var footerNote: some View {
        Text("General information, not medical advice.")
            .font(.system(size: 12))
            .foregroundStyle(PhoneFreeTheme.muted.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }
}

// MARK: - Detail

struct PhoneFreeLearnDetail: View {
    let topic: PhoneFreeLearnTopic

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: topic.symbol)
                        .font(.system(size: 20))
                        .foregroundStyle(PhoneFreeTheme.accent)

                    Text(topic.section.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(PhoneFreeTheme.muted)
                }

                Text(topic.title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(topic.subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(PhoneFreeTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(
                        Array(topic.body.enumerated()),
                        id: \.offset
                    ) { _, block in
                        blockView(block)
                    }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, PhoneFreeTheme.screenPadding)
            .padding(.vertical, 20)
        }
        .background(PhoneFreeTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func blockView(_ block: PhoneFreeLearnBlock) -> some View {
        switch block {
        case let .paragraph(text):
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

        case let .heading(text):
            Text(text)
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(PhoneFreeTheme.accent)
                .padding(.top, 4)

        case let .bullets(items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(PhoneFreeTheme.accent)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)

                        Text(item)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case let .note(text):
            PhoneFreeCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(PhoneFreeTheme.accent)

                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview {
    PhoneFreeLearnView()
        .environment(PhoneFreeStore())
        .preferredColorScheme(.dark)
}
