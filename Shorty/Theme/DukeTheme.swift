import SwiftUI
import UIKit

/// Duke-blue-forward color system and shared text styles for Shorty.
/// Every color here is a dynamic (light/dark) provider, so the whole app adapts
/// automatically -- text stays legible and surfaces invert properly -- whether dark
/// mode comes from the system setting or the in-app appearance override.
enum DukeTheme {
    private static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let (r, g, b) = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
        })
    }

    /// Official Duke Blue (Pantone 280 C) in light mode; a lighter, more vivid blue in
    /// dark mode so it stays legible as icon/text color against a dark background.
    static let dukeBlue = adaptive(light: (0, 26, 87), dark: (94, 151, 246))
    static let dukeBlueLight = adaptive(light: (0, 83, 155), dark: (140, 190, 255))
    static let dukeBlueDeep = adaptive(light: (0, 17, 58), dark: (30, 60, 130))

    static let paper = adaptive(light: (247, 248, 250), dark: (10, 12, 18))
    static let card = adaptive(light: (255, 255, 255), dark: (28, 30, 36))
    static let ink = adaptive(light: (17, 20, 26), dark: (245, 246, 248))
    static let inkMuted = adaptive(light: (96, 102, 112), dark: (162, 168, 178))
    static let divider = adaptive(light: (227, 230, 236), dark: (58, 61, 70))

    static let available = adaptive(light: (33, 148, 105), dark: (48, 189, 133))
    static let occupied = adaptive(light: (196, 88, 42), dark: (224, 120, 72))
    static let pending = adaptive(light: (196, 148, 26), dark: (224, 178, 50))

    static let cardCornerRadius: CGFloat = 20
    static let controlCornerRadius: CGFloat = 14
}

extension Font {
    static let shortyLargeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let shortyTitle = Font.system(.title2, design: .rounded).weight(.semibold)
    static let shortyHeadline = Font.system(.headline, design: .rounded).weight(.semibold)
    static let shortyBody = Font.system(.body, design: .rounded)
    static let shortyCaption = Font.system(.caption, design: .rounded)
}

/// A flat card container matching Shorty's visual language.
struct ShortyCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(18)
        .background(DukeTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: DukeTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DukeTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(DukeTheme.divider, lineWidth: 1)
        )
    }
}

struct ShortyBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(DukeTheme.paper.ignoresSafeArea())
    }
}

/// Toolbar/navigation-bar chrome doesn't always re-resolve a dynamic `UIColor`-backed
/// `Color` the same way ordinary view content does, which is what left "Hello, Finn"
/// unreadable in dark mode even after DukeTheme's colors became dynamic -- reading
/// `\.colorScheme` directly here sidesteps that and is guaranteed correct.
private struct ShortyHeaderTitle: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(colorScheme == .dark ? Color.white : DukeTheme.ink)
    }
}

extension View {
    func shortyBackground() -> some View {
        modifier(ShortyBackground())
    }

    /// Outlined, bordered treatment for secondary buttons and unselected chips: a thin
    /// colored border over the card surface, rather than the same flat colored-tint fill
    /// repeated identically on every control in the app. `isSelected: true` instead fills
    /// solid with `tint` and drops the border, matching the "chosen" state used
    /// throughout. `shape` lets the same treatment work for rectangles, capsules, and
    /// circles alike.
    func shortyChip<S: InsettableShape>(_ shape: S, isSelected: Bool = false, tint: Color = DukeTheme.dukeBlue) -> some View {
        self
            .background(isSelected ? tint : DukeTheme.card)
            .overlay(shape.strokeBorder(isSelected ? Color.clear : tint.opacity(0.45), lineWidth: 1.25))
            .clipShape(shape)
    }

    /// Bold, centered screen title sitting in the compact nav bar rather than a tall
    /// left-aligned large title.
    func shortyHeader(_ title: String) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ShortyHeaderTitle(title: title)
                }
            }
    }
}
