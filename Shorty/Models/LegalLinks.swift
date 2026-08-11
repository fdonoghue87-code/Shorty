import Foundation

/// Shared URLs for the privacy policy and terms, hosted as plain pages via GitHub Pages --
/// no backend of Shorty's own needed just to serve two static documents.
enum LegalLinks {
    static let privacyPolicy = URL(string: "https://fdonoghue87-code.github.io/Shorty/PRIVACY.html")!
    static let termsAndConditions = URL(string: "https://fdonoghue87-code.github.io/Shorty/TERMS.html")!
}
