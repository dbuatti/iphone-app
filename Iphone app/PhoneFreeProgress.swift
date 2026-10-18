//
//  PhoneFreeProgress.swift
//  Iphone app
//
//  How "how close am I?" looks.
//
//  A goal running down and a stretch away climbing towards its next target are
//  both a march towards a finish line, and the app shows that march in one of
//  three shapes. Which one is a preference, not a mode: the number, and the
//  rules behind it, are identical whatever is chosen.
//
//  The default is water, because a card quietly filling up is the version that
//  reads without being looked at — which is the point for a brain that would
//  rather not stare at a progress bar.
//

import SwiftUI

/// The progress treatments offered in Settings.
enum PhoneFreeProgressStyle: String, CaseIterable, Identifiable {
    case water
    case bar
    case ring

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water: "Water"
        case .bar: "Bar"
        case .ring: "Ring"
        }
    }

    var symbol: String {
        switch self {
        case .water: "drop.fill"
        case .bar: "rectangle.bottomhalf.inset.filled"
        case .ring: "circle.dashed"
        }
    }

    var detail: String {
        switch self {
        case .water:
            "The card fills from the bottom as you get closer. Quiet, and "
            + "hard to miss."
        case .bar:
            "A thin bar under the number. The plainest of the three."
        case .ring:
            "A ring around the number, like a dial winding up."
        }
    }
}

// MARK: - The treatments

/// A ring with its content in the middle — the `.ring` treatment.
struct PhoneFreeRingMeter<Content: View>: View {
    var progress: Double
    var tint: Color = PhoneFreeTheme.accent
    var diameter: CGFloat = 200
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.07), lineWidth: 12)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            content
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int(clamped * 100)) percent")
    }

    private var clamped: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }
}

/// A soft wall of colour rising through a card — the `.water` treatment. It sits
/// behind the content, so the number stays fully readable at every level.
struct PhoneFreeWaterFill: View {
    var progress: Double
    var tint: Color = PhoneFreeTheme.accent

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
                * CGFloat(min(max(progress, 0), 1))

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                LinearGradient(
                    colors: [tint.opacity(0.30), tint.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(tint.opacity(0.6))
                        .frame(height: 2)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The plain capsule bar — the `.bar` treatment.
struct PhoneFreeBarMeter: View {
    var progress: Double
    var tint: Color = PhoneFreeTheme.accent
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(tint)
                    .frame(
                        width: geometry.size.width
                            * CGFloat(min(max(progress, 0), 1))
                    )
            }
        }
        .frame(height: height)
    }
}
