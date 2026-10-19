import SwiftUI

struct ExportView: View {
    let home: Home
    @Environment(ProStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var includePhotos = true
    @State private var usePassword = false
    @State private var password = ""
    @State private var pdfURL: URL?
    @State private var csvURL: URL?
    @State private var working = false
    @State private var errorText: String?
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    row("Items", "\(home.itemCount)")
                    row("Estimated value", Money.string(home.totalValue))
                    row("Need proof", "\(home.needsProofCount)")
                    if home.needsDetailsCount > 0 {
                        Label("\(home.needsDetailsCount) items still need a name or value.", systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                } footer: {
                    if home.needsReviewCount > 0 {
                        Text("You can still export now. To fix these first, tap Done, then tap Review on the home page.")
                    }
                }

                Section {
                    Toggle("Include photos", isOn: $includePhotos)
                    Toggle(isOn: Binding(
                        get: { usePassword },
                        set: { newValue in
                            if newValue && !store.isPro {
                                showPaywall = true
                            } else {
                                usePassword = newValue
                            }
                        })) {
                        HStack {
                            Text("Lock with a password")
                            if !store.isPro { Pill(text: "PRO", color: .accentColor) }
                        }
                    }
                    if usePassword {
                        SecureField("Password", text: $password)
                            .textContentType(.newPassword)
                    }
                    if let pdfURL {
                        ShareLink(item: pdfURL) {
                            Label("Share or save PDF", systemImage: "square.and.arrow.up")
                                .font(.headline)
                        }
                    } else {
                        Button {
                            makePDF()
                        } label: {
                            HStack {
                                Label("Create PDF", systemImage: "doc.richtext")
                                    .font(.headline)
                                if working {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(working || (usePassword && password.isEmpty) || home.allItems.isEmpty)
                    }
                } header: {
                    Text("PDF record")
                } footer: {
                    Text("Save a copy somewhere outside your home: email it to yourself or put it in Files or iCloud Drive.")
                }

                Section {
                    if store.isPro {
                        if let csvURL {
                            ShareLink(item: csvURL) {
                                Label("Share spreadsheet", systemImage: "square.and.arrow.up")
                            }
                        } else {
                            Button {
                                makeCSV()
                            } label: {
                                Label("Create spreadsheet (CSV)", systemImage: "tablecells")
                            }
                            .disabled(home.allItems.isEmpty)
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Spreadsheet export", systemImage: "tablecells")
                                Spacer()
                                Pill(text: "PRO", color: .accentColor)
                            }
                        }
                    }
                } header: {
                    Text("Spreadsheet")
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: includePhotos) { _, _ in pdfURL = nil }
            .onChange(of: usePassword) { _, _ in pdfURL = nil }
            .onChange(of: password) { _, _ in pdfURL = nil }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("Couldn't export", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func makePDF() {
        working = true
        let report = ReportData(home: home, includePhotos: includePhotos)
        let secret = usePassword ? password : nil
        Task.detached(priority: .userInitiated) {
            do {
                let url = try PDFExporter.writePDF(report, password: secret)
                await MainActor.run {
                    pdfURL = url
                    working = false
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

    private func makeCSV() {
        let report = ReportData(home: home, includePhotos: false)
        do {
            csvURL = try PDFExporter.writeCSV(report)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
