import SwiftUI
import StoreKit

/// Buy scan credits. Shown when a scan is started with none left.
struct ScanCreditsView: View {
    @Environment(ScanStore.self) private var scans
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "video.badge.waveform.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(Color.rpRecordDeep)
                        .padding(.top, 12)
                    VStack(spacing: 6) {
                        Text("Room scans")
                            .font(.largeTitle.bold())
                        Text("Film a room. Get the list.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        benefit("video.fill", "One walkthrough per room", "A minute or two of video, no snapping.")
                        benefit("list.bullet.rectangle.fill", "Items, brands, values", "Labels are read for model and serial numbers.")
                        benefit("checkmark.circle.fill", "You approve before anything is saved", "Swipe off mistakes, tap to fix a value.")
                        benefit("hand.raised.fill", "Nothing is stored", "Frames are processed and discarded.")
                    }
                    .card()

                    if scans.products.isEmpty {
                        Text("Scan packs aren't available right now. Check your connection, or try again later.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(scans.products, id: \.id) { product in
                                Button {
                                    Task { await scans.buy(product) }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(scans.scansIn(product)) room scans").font(.headline)
                                            Text(perScan(product)).font(.footnote).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(product.displayPrice).font(.headline)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.rpCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(scans.purchasing)
                            }
                        }
                    }

                    Text("Credits stay on this iPhone and never expire. \(scans.balanceLine).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Color.rpGround)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
            .task { if scans.products.isEmpty { await scans.loadProducts() } }
            .alert("Room scans", isPresented: Binding(
                get: { scans.message != nil },
                set: { if !$0 { scans.message = nil } })) {
                Button("OK", role: .cancel) {
                    if scans.credits > 0 { dismiss() }
                }
            } message: {
                Text(scans.message ?? "")
            }
        }
    }

    private func perScan(_ product: Product) -> String {
        let n = Decimal(scans.scansIn(product))
        let each = product.price / n
        return "\(each.formatted(product.priceFormatStyle)) per room"
    }

    private func benefit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
