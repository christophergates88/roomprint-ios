import Foundation
import StoreKit

/// One-time "Roomprint Pro" unlock using StoreKit 2. No server needed.
@MainActor
@Observable
final class ProStore {
    private(set) var product: Product?
    private(set) var isPro = false
    private(set) var purchasing = false
    var message: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
        Task { [weak self] in
            await self?.refreshEntitlement()
            await self?.loadProduct()
        }
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [AppConfig.proProductID]).first
        } catch {
            product = nil
        }
    }

    func refreshEntitlement() async {
        var unlocked = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == AppConfig.proProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isPro = unlocked
    }

    func buy() async {
        if product == nil { await loadProduct() }
        guard let product else {
            message = "Pro isn't available right now. Please try again later."
            return
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                } else {
                    message = "The purchase couldn't be verified. Please contact support."
                }
            case .pending:
                message = "Your purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            message = "Couldn't reach the App Store. Check your connection and try again."
        }
        await refreshEntitlement()
        if !isPro && message == nil {
            message = "No previous Pro purchase was found for this Apple ID."
        }
    }
}
