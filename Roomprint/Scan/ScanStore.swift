import Foundation
import StoreKit

/// AI scan credits: a free first scan, then consumable packs bought with StoreKit 2.
/// Credits live on this device (UserDefaults); the server only enforces daily caps.
@MainActor
@Observable
final class ScanStore {
    private(set) var products: [Product] = []
    private(set) var purchasing = false
    var message: String?

    private let defaults = UserDefaults.standard
    private let creditsKey = "scanCredits"
    private let freeUsedKey = "scanFreeUsed"
    private let seenKey = "scanSeenTransactions"
    private let deviceKey = "scanDeviceID"

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result {
                    await self?.credit(transaction)
                    await transaction.finish()
                }
            }
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.settleUnfinished()
        }
    }

    // MARK: Balance

    /// Paid credits left.
    var credits: Int {
        get { defaults.integer(forKey: creditsKey) }
        set { defaults.set(max(0, newValue), forKey: creditsKey) }
    }

    var freeScansUsed: Int {
        get { defaults.integer(forKey: freeUsedKey) }
        set { defaults.set(max(0, newValue), forKey: freeUsedKey) }
    }

    var freeScansLeft: Int { max(0, AppConfig.freeScans - freeScansUsed) }

    /// Test builds from Xcode never run out, so the flow can be exercised before the store exists.
    var isTestBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    var canScan: Bool { isTestBuild || freeScansLeft > 0 || credits > 0 }

    var balanceLine: String {
        if isTestBuild { return "Test build: scans don't use credits" }
        if freeScansLeft > 0 { return "\(freeScansLeft) free scan left" }
        return credits == 1 ? "1 scan credit" : "\(credits) scan credits"
    }

    /// Takes one scan from the balance. Call after a scan is approved, not before.
    func consumeScan() {
        if isTestBuild { return }
        if freeScansLeft > 0 { freeScansUsed += 1 } else if credits > 0 { credits -= 1 }
    }

    /// A stable id for the daily caps on the server. Not tied to the Apple ID or the phone's serial.
    var deviceID: String {
        if let id = defaults.string(forKey: deviceKey) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: deviceKey)
        return id
    }

    // MARK: Store

    func loadProducts() async {
        do {
            let found = try await Product.products(for: AppConfig.scanProductIDs)
            products = found.sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    func scansIn(_ product: Product) -> Int {
        product.id == AppConfig.scans10ProductID ? 10 : 3
    }

    func buy(_ product: Product) async {
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await credit(transaction)
                    await transaction.finish()
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

    /// Adds credits for a consumable transaction exactly once.
    private func credit(_ transaction: StoreKit.Transaction) async {
        guard AppConfig.scanProductIDs.contains(transaction.productID), transaction.revocationDate == nil else { return }
        var seen = defaults.array(forKey: seenKey) as? [String] ?? []
        let key = String(transaction.id)
        guard !seen.contains(key) else { return }
        seen.append(key)
        if seen.count > 200 { seen.removeFirst(seen.count - 200) }
        defaults.set(seen, forKey: seenKey)
        let packSize = transaction.productID == AppConfig.scans10ProductID ? 10 : 3
        credits += packSize * max(1, transaction.purchasedQuantity)
        message = "Added \(packSize) scans. You have \(credits) scan credits."
    }

    /// Purchases interrupted before the app could record them.
    private func settleUnfinished() async {
        for await result in StoreKit.Transaction.unfinished {
            if case .verified(let transaction) = result {
                await credit(transaction)
                await transaction.finish()
            }
        }
    }
}
