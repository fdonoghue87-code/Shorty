import StoreKit
import SwiftUI
import UIKit

/// The Shorty Plus paywall. Shown either from Settings or automatically when someone
/// hits a free-tier limit (a second standing arrangement, a 4th schedule import).
struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionStore.self) private var subscriptionStore

    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44))
                            .foregroundStyle(DukeTheme.dukeBlue)
                        Text("Shorty Plus")
                            .font(.shortyLargeTitle)
                            .foregroundStyle(DukeTheme.dukeBlue)
                        Text("A small monthly upgrade for roommates who use Shorty a lot.")
                            .font(.shortyBody)
                            .foregroundStyle(DukeTheme.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    ShortyCard {
                        BenefitRow(icon: "repeat", title: "Unlimited Standing Arrangements", detail: "Free includes one active standing arrangement at a time.")
                        Divider()
                        BenefitRow(icon: "square.and.arrow.down", title: "Unlimited Schedule Imports", detail: "Free includes 3 calendar or photo imports total.")
                    }

                    if subscriptionStore.isPlus {
                        Label("You're subscribed to Shorty Plus", systemImage: "checkmark.seal.fill")
                            .font(.shortyHeadline)
                            .foregroundStyle(DukeTheme.available)
                    } else if let product = subscriptionStore.products.first {
                        PrimaryButton(title: "Subscribe — \(product.displayPrice)/month", systemImage: "sparkles", isLoading: isPurchasing) {
                            purchase(product)
                        }
                    } else if subscriptionStore.isLoading {
                        ProgressView()
                    } else {
                        Text("Couldn't load the subscription right now. Try again in a moment.")
                            .font(.shortyCaption)
                            .foregroundStyle(DukeTheme.inkMuted)
                    }

                    Button("Restore Purchases") {
                        Task { await subscriptionStore.restorePurchases() }
                    }
                    .font(.shortyCaption)
                    .foregroundStyle(DukeTheme.dukeBlue)

                    if let error = subscriptionStore.lastError {
                        Text(error)
                            .font(.shortyCaption)
                            .foregroundStyle(DukeTheme.occupied)
                    }

                    VStack(spacing: 6) {
                        if let product = subscriptionStore.products.first {
                            Text("Shorty Plus renews automatically every month at \(product.displayPrice) until you cancel. Manage or cancel anytime in your Apple ID account settings.")
                                .font(.shortyCaption)
                                .foregroundStyle(DukeTheme.inkMuted)
                                .multilineTextAlignment(.center)
                        }
                        HStack(spacing: 16) {
                            Button("Privacy Policy") {
                                UIApplication.shared.open(LegalLinks.privacyPolicy)
                            }
                            Button("Terms & Conditions") {
                                UIApplication.shared.open(LegalLinks.termsAndConditions)
                            }
                        }
                        .font(.shortyCaption)
                        .foregroundStyle(DukeTheme.dukeBlue)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .shortyBackground()
            .navigationTitle("Shorty Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await subscriptionStore.loadProducts()
            }
        }
    }

    private func purchase(_ product: Product) {
        isPurchasing = true
        Task {
            await subscriptionStore.purchase(product)
            isPurchasing = false
        }
    }
}

private struct BenefitRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(DukeTheme.dukeBlue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.shortyHeadline)
                Text(detail).font(.shortyCaption).foregroundStyle(DukeTheme.inkMuted)
            }
        }
    }
}
