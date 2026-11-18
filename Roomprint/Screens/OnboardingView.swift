import SwiftUI

struct OnboardingView: View {
    var onDone: () -> Void
    @State private var page = 0

    private struct Page {
        let symbol: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(symbol: "video.badge.waveform.fill",
             title: "Film a room. Get the list.",
             body: "Walk slowly through a room with your camera. Roomprint lists what's in it, with brands and estimated replacement values."),
        Page(symbol: "checkmark.circle.fill",
             title: "You approve every item",
             body: "Swipe off mistakes and fix any value before anything is saved. Snap or add single items any time."),
        Page(symbol: "doc.richtext.fill",
             title: "Ready for any claim",
             body: "Export a clean PDF of everything you own, room by room. Your records stay private on your iPhone.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 24) {
                        Spacer()
                        if index == 0 {
                            LogoMark(size: 112)
                        } else {
                            Image(systemName: pages[index].symbol)
                                .font(.system(size: 72, weight: .semibold))
                                .foregroundStyle(Color.rpRecord)
                                .frame(height: 112)
                        }
                        Text(pages[index].title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(pages[index].body)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onDone()
                }
            } label: {
                Text(page < pages.count - 1 ? "Next" : "Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.rpGround)
    }
}
