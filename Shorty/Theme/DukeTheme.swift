import SwiftUI

/// Duke-blue-forward color system and shared text styles for Shorty.
enum DukeTheme {
    /// Official Duke Blue (Pantone 280 C).
    static let dukeBlue = Color(red: 0 / 255, green: 26 / 255, blue: 87 / 255)
    static let dukeBlueLight = Color(red: 0 / 255, green: 83 / 255, blue: 155 / 255)
    static let dukeBlueDeep = Color(red: 0 / 255, green: 17 / 255, blue: 58 / 255)

    static let paper = Color(red: 247 / 255, green: 248 / 255, blue: 250 / 255)
    static let card = Color.white
    static let ink = Color(red: 17 / 255, green: 20 / 255, blue: 26 / 255)
    static let inkMuted = Color(red: 96 / 255, green: 102 / 255, blue: 112 / 255)
    static let divider = Color(red: 227 / 255, green: 230 / 255, blue: 236 / 255)

    static let available = Color(red: 33 / 255, green: 148 / 255, blue: 105 / 255)
    static let occupied = Color(red: 196 / 255, green: 88 / 255, blue: 42 / 255)
    static let pending = Color(red: 196 / 255, green: 148 / 255, blue: 26 / 255)

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

extension View {
    func shortyBackground() -> some View {
        modifier(ShortyBackground())
    }
}
