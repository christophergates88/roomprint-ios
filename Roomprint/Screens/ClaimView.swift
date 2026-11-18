import SwiftUI

/// After a fire, theft, storm or leak: pick what was lost or damaged and get the list the insurer asks for.
struct ClaimView: View {
    @Bindable var home: Home
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var shareURL: IdentifiedURL?
    @State private var preview: IdentifiedURL?
    @State private var errorText: String?
    @State private var confirmClear = false

    static let causes = ["Fire", "Theft", "Storm or wind", "Water", "Other"]

    private var hasDate: Binding<Date> {
        Binding(get: { home.lossDate ?? Date() }, set: { home.lossDate = $0 })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("What happened", selection: $home.lossCause) {
                        Text("Choose").tag("")
                        ForEach(Self.causes, id: \.self) { Text($0).tag($0) }
                    }
                    DatePicker("Date of loss", selection: hasDate, in: ...Date(), displayedComponents: .date)
                    TextField("Claim number (if you have one)", text: $home.claimNumber)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("The loss").textCase(nil)
                }

                Section {
                    firstStep("phone.fill", "Call your insurer or agent and get a claim number.")
                    firstStep("camera.fill", "Photograph the damage before anything is moved or cleaned.")
                    firstStep("shippingbox.fill", "Keep damaged items until the adjuster has seen them.")
                    firstStep("receipt", "Save receipts for hotels, meals and emergency repairs.")
                } header: {
                    Text("First steps").textCase(nil)
                }

                Section {
                    Button {
                        setAll(home.allItems, to: "lost")
                    } label: {
                        Label("Everything was lost", systemImage: "checklist.checked")
                    }
                    if !home.claimedItems.isEmpty {
                        Button(role: .destructive) {
                            confirmClear = true
                        } label: {
                            Label("Clear the list", systemImage: "xmark.circle")
                        }
                    }
                } footer: {
                    Text("Or tap items below. Tap once for lost, twice for damaged, three times to take it off.")
                }

                ForEach(home.sortedRooms.filter { !$0.items.isEmpty }) { room in
                    Section {
                        ForEach(room.items.sorted { $0.totalValue > $1.totalValue }) { item in
                            Button {
                                cycle(item)
                            } label: {
                                ClaimRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text(room.name)
                            Spacer()
                            Button(room.items.allSatisfy { $0.isClaimed } ? "Clear room" : "Whole room") {
                                let all = room.items.allSatisfy { $0.isClaimed }
                                setAll(room.items, to: all ? "" : "lost")
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                        .textCase(nil)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.rpGround)
            .navigationTitle("Claim list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sheet(item: $shareURL) { file in ActivitySheet(url: file.url) }
            .sheet(item: $preview) { file in
                PDFPreviewView(url: file.url, title: "\(home.name) claim list")
            }
            .confirmationDialog("Clear the claim list?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear it", role: .destructive) { setAll(home.allItems, to: "") }
            } message: {
                Text("Your items stay in the record. Only the lost and damaged marks are removed.")
            }
            .alert("Couldn't make the file", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
            .onAppear {
                if home.lossDate == nil { home.lossDate = Date() }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(home.claimedItems.count == 1 ? "1 entry on the list" : "\(home.claimedItems.count) entries on the list")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Money.string(home.claimedValue))
                        .font(.title2.bold())
                        .monospacedDigit()
                }
                Spacer()
                if working { ProgressView() }
            }
            HStack(spacing: 12) {
                Button {
                    make(.pdf)
                } label: {
                    Label("Claim PDF", systemImage: "doc.richtext")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.rpRecordDeep)

                Button {
                    make(.csv)
                } label: {
                    Label("Spreadsheet", systemImage: "tablecells")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .disabled(home.claimedItems.isEmpty || working)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.bar)
    }

    private func firstStep(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.subheadline)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Color.accentColor)
        }
    }

    // MARK: Actions

    private func cycle(_ item: Item) {
        switch item.lossStatus {
        case "": item.lossStatus = "lost"
        case "lost": item.lossStatus = "damaged"
        default: item.lossStatus = ""
        }
        Haptics.tap()
    }

    private func setAll(_ items: [Item], to status: String) {
        for item in items { item.lossStatus = status }
        Haptics.tap()
    }

    private enum Kind { case pdf, csv }

    private func make(_ kind: Kind) {
        working = true
        let report = ReportData(home: home, includePhotos: true, claimOnly: true)
        Task.detached(priority: .userInitiated) {
            do {
                let url = try (kind == .pdf ? PDFExporter.writePDF(report, password: nil) : PDFExporter.writeCSV(report))
                await MainActor.run {
                    working = false
                    if kind == .pdf { preview = IdentifiedURL(url: url) } else { shareURL = IdentifiedURL(url: url) }
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    working = false
                }
            }
        }
    }
}

private struct ClaimRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isClaimed ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(item.isClaimed ? Color.rpRecordDeep : Color.secondary)
            Thumb(data: item.coverThumb, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.quantity > 1 ? "\(item.displayName) ×\(item.quantity)" : item.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if item.isClaimed {
                    Text(item.lossStatus == "damaged" ? "Damaged" : "Lost or destroyed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rpRecordDeep)
                } else if !item.detailLine.isEmpty {
                    Text(item.detailLine).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Text(Money.string(item.totalValue))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
