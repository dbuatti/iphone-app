//
//  PhoneFreeTheme.swift
//  Iphone app
//
//  One place for the colours and spacing every screen uses, so the app looks
//  like one app instead of several. Kept deliberately small: this is meant to
//  feel calm, not busy.
//

import SwiftUI

enum PhoneFreeTheme {
    /// Deep navy behind everything.
    static let background = Color(red: 0.055, green: 0.065, blue: 0.12)

    /// Mint — the "you're doing the right thing" colour.
    static let accent = Color(red: 0.65, green: 0.91, blue: 0.79)

    /// Secondary text.
    static let muted = Color(red: 0.62, green: 0.65, blue: 0.74)

    /// Raised surface (cards).
    static let card = Color.white.opacity(0.05)

    /// Hairline around cards.
    static let cardBorder = Color.white.opacity(0.08)

    /// Larger surface for grouped content.
    static let surface = Color.white.opacity(0.035)

    static let cornerRadius: CGFloat = 16
    static let screenPadding: CGFloat = 20
}

// MARK: - Text size
//
// Text follows the iPhone's text-size setting. Most text uses the built-in
// text styles (.caption, .subheadline…). Where a screen needs a size that has
// no matching style — the big counters, small all-caps labels — `scaledFont`
// keeps that exact size at the default setting and scales it from there.

private struct PhoneFreeScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    init(
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design,
        relativeTo style: Font.TextStyle
    ) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    /// A system font at `size` points at the default text size, scaled with
    /// the user's text-size setting like `style` is.
    func scaledFont(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo style: Font.TextStyle = .body
    ) -> some View {
        modifier(
            PhoneFreeScaledFont(
                size: size,
                weight: weight,
                design: design,
                relativeTo: style
            )
        )
    }
}

/// Lays its children out side by side, or one above the other when the user
/// has picked one of the larger accessibility text sizes and side by side
/// would squash them.
struct PhoneFreeAdaptiveStack<Content: View>: View {
    var spacing: CGFloat = 12
    var horizontalAlignment: HorizontalAlignment = .leading
    var verticalAlignment: VerticalAlignment = .center
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(
                VStackLayout(alignment: horizontalAlignment, spacing: spacing)
            )
            : AnyLayout(
                HStackLayout(alignment: verticalAlignment, spacing: spacing)
            )

        layout { content }
    }
}

/// A full-screen column that keeps its Spacers at the default text size but
/// scrolls instead of clipping when large text makes it taller than the
/// screen.
struct PhoneFreeFillingScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                content
                    .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

// MARK: - Reusable pieces

/// A raised card used all over the app. One shape, one padding — so the eye
/// always knows what is a "thing you can read" versus "a thing you can tap".
struct PhoneFreeCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PhoneFreeTheme.card)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PhoneFreeTheme.cornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PhoneFreeTheme.cornerRadius,
                    style: .continuous
                )
                .stroke(PhoneFreeTheme.cardBorder, lineWidth: 1)
            }
    }
}

/// A small all-caps label. Used to name a section so a screen never leaves the
/// user guessing what they are looking at.
struct PhoneFreeSectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .tracking(1.8)
            .foregroundStyle(PhoneFreeTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The app's one primary button shape. Filled mint — reserved for the single
/// most important action on a screen, so "what do I do here?" is never a
/// question.
struct PhoneFreePrimaryButton: View {
    let title: String
    var symbol: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let symbol {
                    Image(systemName: symbol)
                }

                Text(title)
                    .font(.headline)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .foregroundStyle(PhoneFreeTheme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .frame(minHeight: 58)
            .background(PhoneFreeTheme.accent)
            .clipShape(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

/// A quieter button — outlined, for the second-most important action.
struct PhoneFreeSecondaryButton: View {
    let title: String
    var symbol: String?
    var tint: Color = PhoneFreeTheme.muted
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                }

                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .frame(minHeight: 50)
            .background(Color.white.opacity(0.04))
            .clipShape(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(PhoneFreeTheme.cardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Time formatting

enum PhoneFreeFormat {
    /// "0:42", "12:05", "3:07:44" — the clock style used for live counters.
    static func clock(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60

        if hours > 0 {
            return String(
                format: "%d:%02d:%02d",
                hours,
                minutes,
                remainder
            )
        }

        return String(format: "%d:%02d", minutes, remainder)
    }

    /// "45m", "2h 10m", "3h" — for totals, not live counters.
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))

        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let rest = minutes % 60

        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }

    /// "just now", "12 min ago", "2h ago" — for history rows.
    static func ago(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))

        if seconds < 60 {
            return "just now"
        }

        return "\(duration(TimeInterval(seconds))) ago"
    }
}
