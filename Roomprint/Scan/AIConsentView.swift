import SwiftUI

/// Asked once, before the first room scan: what leaves the phone, who gets it, what happens to it.
/// Nothing is sent until the person taps Allow (App Review Guideline 5.1.2(i): third-party AI).
struct AIConsentView: View {
    let onAllow: () -> Void
    let onDecline: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(Color.rpRecordDeep)
                    Spacer()
                }
                .padding(.top, 20)

                Text("Room scans use Claude, an AI from Anthropic")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                Text("To list what's in a room, Roomprint has to send parts of your video off this iPhone. Here's exactly what happens.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 16) {
                    point("photo.stack.fill", "What is sent",
                          "Still frames from the walkthrough video, label text your iPhone reads from them, and the room's name. Never the audio, and nothing else from the app.")
                    point("arrow.up.forward.app.fill", "Who receives it",
                          "Roomprint's scan service, which passes the frames to Anthropic's Claude AI to name each item and estimate its value.")
                    point("trash.fill", "What happens to it",
                          "It is used only to make your list. Roomprint doesn't keep the frames. Anthropic doesn't use them to train its AI and deletes them within 30 days.")
                    point("iphone", "What stays here",
                          "Your homes, items, photos and records stay on this iPhone.")
                }
                .card()

                Text("You can change this any time in Settings. Without it, you can still add items yourself with Snap item and Add item.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Link("Read the privacy policy", destination: AppConfig.privacyURL)
                    .font(.footnote.weight(.semibold))
            }
            .padding()
        }
        .background(Color.rpGround)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(action: onAllow) {
                    Text("Allow and continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.rpRecordDeep)
                .controlSize(.large)

                Button("Not now", action: onDecline)
                    .font(.headline)
                    .controlSize(.large)
            }
            .padding()
            .background(.bar)
        }
    }

    private func point(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
