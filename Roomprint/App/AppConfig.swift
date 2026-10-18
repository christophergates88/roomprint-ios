import Foundation

/// Everything you may need to change before release lives here.
enum AppConfig {
    /// Must match the In-App Purchase product ID you create in App Store Connect.
    static let proProductID = "com.christophergates.roomprint.pro"

    /// Free tier limits. Pro removes them.
    static let freeHomeLimit = 1
    static let freeItemLimit = 30

    /// Your website, used for "Book a Roomprint visit". This points at the public
    /// Roomprint site draft for now; change it to your own domain once it is live.
    static let serviceURL = URL(string: "https://claude.ai/artifact/452tB6iHLG4squeqg53wfv")!
    /// Privacy policy. Apple requires this to be a working public page before review.
    /// Served from docs/privacy.html by GitHub Pages; change it when the domain is live.
    static let privacyURL = URL(string: "https://christophergates88.github.io/roomprint-ios/privacy.html")!
    /// Apple's standard end-user license agreement, shown on the paywall.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
