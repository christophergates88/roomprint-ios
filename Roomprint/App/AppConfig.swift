import Foundation

/// Everything you may need to change before release lives here.
enum AppConfig {
    /// Must match the In-App Purchase product ID you create in App Store Connect.
    static let proProductID = "com.christophergates.roomprint.pro"

    /// Free tier limits. Pro removes them. Items created by an AI scan never count against them.
    static let freeHomeLimit = 1
    static let freeItemLimit = 30

    // MARK: AI room scans

    /// The scan service (a Cloudflare Worker). Frames are sent here, passed to the model, and not stored.
    static let scanServiceURL = URL(string: "https://roomprint-scan.christophergates88.workers.dev/scan")!
    /// Shared key the service expects in the X-Roomprint-Key header. Set the same value as the
    /// Worker's APP_KEY secret. It only stops strangers from running scans on our credits.
    static let scanAppKey = "rp-scan-2026-k7Qx9mP2vL4nR8tW"
    /// Consumable products: scan credits. Must match App Store Connect (and the StoreKit test file).
    static let scans3ProductID = "com.christophergates.roomprint.scans3"
    static let scans10ProductID = "com.christophergates.roomprint.scans10"
    static let scanProductIDs = [scans3ProductID, scans10ProductID]
    /// Every device gets this many scans before it needs credits.
    static let freeScans = 1
    /// How much video goes to the model: one frame about every `scanFrameInterval` seconds, at most `scanMaxFrames`.
    static let scanFrameInterval: Double = 1.5
    static let scanMaxFrames = 80
    /// Longest edge of an uploaded frame, in pixels. 1024 keeps labels readable and uploads small.
    static let scanFrameMaxSide: CGFloat = 1024

    /// Your website, used for "Book a Roomprint visit". This points at the public
    /// Roomprint site draft for now; change it to your own domain once it is live.
    static let serviceURL = URL(string: "https://claude.ai/artifact/452tB6iHLG4squeqg53wfv")!
    /// Privacy policy. Apple requires this to be a working public page before review.
    /// Served from docs/privacy.html by GitHub Pages; change it when the domain is live.
    static let privacyURL = URL(string: "https://christophergates88.github.io/roomprint-ios/privacy.html")!
    /// Apple's standard end-user license agreement, shown on the paywall.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
