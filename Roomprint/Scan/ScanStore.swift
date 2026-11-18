import Foundation
import StoreKit

/// AI scan credits: a free first scan, then consumable packs bought with StoreKit 2.
///
/// Every build that leaves Xcode (TestFlight, App Review, the App Store) works the same way: one free scan,
/// then credits. Only Debug builds run free, so the real purchase path is what reviewers and testers see.
/// Credits, the free-scan flag and the device id live in the Keychain so they survive a reinstall.
/// The scan service only enforces daily caps.
@MainActor
@Observable
final class ScanStore {
    private(set) var products: [Product] = []
    private(set) var purchasing = false
    var message: String?

    /// Paid credits left.
    private(set) var credits: Int = 0

    /// Free scans already used on this iPhone.
    private(set) var freeScansUsed: Int = 0

    /// The person agreed that room-scan frames may be sent to the scan service and its AI provider
    /// (Anthropic). Asked before the first scan; can be withdrawn in Settings.
    private(set) var aiConsent: Bool = false

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let credits = "scanCredits"
        static let freeUsed = "scanFreeUsed"
        static let seen = "scanSeenTransactions"
        static let device = "scanDeviceID"
        static let consent = AppConfig.aiConsentKey
        static let consentDate = "scanAIConsentDate"
    }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        // Earlier builds kept these in UserDefaults, which a reinstall wipes. Move them over once.
        let oldCredits = defaults.integer(forKey: Keys.credits)
        let oldFreeUsed = defaults.integer(forKey: Keys.freeUsed)
        credits = max(KeychainValue.int(Keys.credits) ?? 0, oldCredits)
        freeScansUsed = max(KeychainValue.int(Keys.freeUsed) ?? 0, oldFreeUsed)
        aiConsent = defaults.bool(forKey: Keys.consent)
        saveBalance()

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

    var freeScansLeft: Int { max(0, AppConfig.freeScans - freeScansUsed) }

    /// Debug builds from Xcode never run out, so the scan flow can be tried before the store is set up.
    /// TestFlight and review builds are charged like the App Store build (TestFlight purchases are free).
    var isDeveloperBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    var scansLeft: Int { freeScansLeft + credits }

    var canScan: Bool { isDeveloperBuild || scansLeft > 0 }

    var balanceLine: String {
        if isDeveloperBuild { return "Developer build: scans are free" }
        if freeScansLeft > 0 && credits == 0 {
            return freeScansLeft == 1 ? "Your first scan is free" : "\(freeScansLeft) free scans left"
        }
        switch scansLeft {
        case 0: return "No scans left"
        case 1: return "1 scan left"
        default: return "\(scansLeft) scans left"
        }
    }

    /// Takes one scan from the balance. Called when a scan returns a list, whether or not it is kept.
    func consumeScan() {
        if isDeveloperBuild { return }
        if freeScansLeft > 0 { freeScansUsed += 1 } else if credits > 0 { credits -= 1 }
        saveBalance()
    }

    /// Records the answer to the AI-sharing question (or its withdrawal in Settings).
    func setAIConsent(_ allowed: Bool) {
        aiConsent = allowed
        defaults.set(allowed, forKey: Keys.consent)
        if allowed { defaults.set(Date(), forKey: Keys.consentDate) }
    }

    private func saveBalance() {
        KeychainValue.set(credits, for: Keys.credits)
        KeychainValue.set(freeScansUsed, for: Keys.freeUsed)
    }

    /// A stable random id for the daily caps on the server. Not tied to the Apple ID, the phone's serial
    /// or anything else about the person. Kept in the Keychain so a reinstall keeps the same limits.
    var deviceID: String {
        if let id = KeychainValue.string(Keys.device) { return id }
        let id = defaults.string(forKey: Keys.device) ?? UUID().uuidString
        KeychainValue.set(id, for: Keys.device)
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
                    message = "The purchase couldn't be verified. Please contact support@getroomprint.com."
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
        var seen = defaults.array(forKey: Keys.seen) as? [String] ?? []
        let key = String(transaction.id)
        guard !seen.contains(key) else { return }
        seen.append(key)
        if seen.count > 200 { seen.removeFirst(seen.count - 200) }
        defaults.set(seen, forKey: Keys.seen)
        let packSize = transaction.productID == AppConfig.scans10ProductID ? 10 : 3
        credits += packSize * max(1, transaction.purchasedQuantity)
        saveBalance()
        message = "Added \(packSize) room scans. \(balanceLine)."
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
