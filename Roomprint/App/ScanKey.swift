// The shared key the scan service expects in the X-Roomprint-Key header (the Worker's APP_KEY secret).
// It only stops strangers from running scans on Roomprint's AI credits.
//
// "Ship Roomprint.command" replaces this value with the private key kept on the Mac
// (~/.roomprint/scan-key) just for the App Store build, then puts this file back, so the key that
// actually works is never in the public repo. Leave this line's format as it is: the script rewrites it.
enum ScanKey {
    static let value = "rp-scan-2026-k7Qx9mP2vL4nR8tW"
}
