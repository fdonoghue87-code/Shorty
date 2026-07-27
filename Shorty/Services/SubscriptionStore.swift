import Foundation
import StoreKit

/// Tracks the "Shorty Plus" monthly subscription via StoreKit 2. This is Apple's actual
/// supported monetization path for unlocking app features (unlike payment processing for
/// the peer-to-peer room-time payments, which Shorty deliberately stays out of).
@Observable
final class SubscriptionStore {
    static let plusMonthlyID = "com.fdonoghue.shorty.plus.monthly"

    private(set) var products: [Product] = []
    private(set) var isPlus = false
    private(set) var isLoading = false
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactionUpdates()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [Self.plusMonthlyID])
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.plusMonthlyID {
                active = transaction.revocationDate == nil
            }
        }
        isPlus = active
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
