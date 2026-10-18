import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @Environment(ProStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lockEnabled") private var lockEnabled = false
    @State private var showPaywall = false
    @State private var lockError: String?

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if store.isPro {
                        HStack {
                            LogoMark(size: 36)
                            VStack(alignment: .leading) {
                                Text("Roomprint Pro").font(.headline)
                                Text("Unlocked. Thank you!").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                LogoMark(size: 36)
                                VStack(alignment: .leading) {
                                    Text("Upgrade to Pro").font(.headline).foregroundStyle(Color.primary)
                                    Text("Unlimited homes and items").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { lockEnabled },
                        set: { setLock($0) }
                    )) {
                        Label("Lock with Face ID", systemImage: "faceid")
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Your records stay on this iPhone. Roomprint doesn't upload your photos or details anywhere. They're included in your regular iPhone backup.")
                }

                Section {
                    Link(destination: AppConfig.serviceURL) {
                        Label("Book a Roomprint visit", systemImage: "person.crop.circle.badge.checkmark")
                    }
                } header: {
                    Text("Rather have us do it?")
                } footer: {
                    Text("In central Georgia, we can record your home for you in about an hour.")
                }

                Section {
                    Button("Restore purchase") {
                        Task { await store.restore() }
                    }
                    Link("Privacy policy", destination: AppConfig.privacyURL)
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("Face ID", isPresented: Binding(get: { lockError != nil }, set: { if !$0 { lockError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(lockError ?? "")
            }
            .alert("Roomprint Pro", isPresented: Binding(
                get: { store.message != nil && !showPaywall },
                set: { if !$0 { store.message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.message ?? "")
            }
        }
    }

    private func setLock(_ on: Bool) {
        guard on else {
            lockEnabled = false
            return
        }
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            lockEnabled = true
        } else {
            lockError = "Set up a passcode or Face ID on your iPhone first."
        }
    }
}

struct PaywallView: View {
    @Environment(ProStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    LogoMark(size: 76)
                        .padding(.top, 12)
                    VStack(spacing: 6) {
                        Text("Roomprint Pro")
                            .font(.largeTitle.bold())
                        Text("One purchase. Yours for good.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        benefit("house.and.flag.fill", "Unlimited homes",
                                "Record a rental, a lake house or a parent's home.")
                        benefit("infinity", "Unlimited items",
                                "No cap on what you record.")
                        benefit("lock.doc.fill", "Password-protected PDFs",
                                "Lock your record before you share it.")
                        benefit("tablecells", "Spreadsheet export",
                                "Open every item in Numbers or Excel.")
                    }
                    .card()

                    Text("Free includes 1 home and up to \(AppConfig.freeItemLimit) items.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(Color.rpGround)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        Task { await store.buy() }
                    } label: {
                        Group {
                            if store.purchasing {
                                ProgressView()
                            } else if let product = store.product {
                                Text("Unlock for \(product.displayPrice)")
                            } else {
                                Text("Unlock Pro")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.purchasing)

                    Button("Restore purchase") {
                        Task { await store.restore() }
                    }
                    .font(.footnote)

                    HStack(spacing: 14) {
                        Link("Privacy policy", destination: AppConfig.privacyURL)
                        Link("Terms of use", destination: AppConfig.termsURL)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
            .onChange(of: store.isPro) { _, unlocked in
                if unlocked {
                    Haptics.success()
                    dismiss()
                }
            }
            .alert("Roomprint Pro", isPresented: Binding(
                get: { store.message != nil },
                set: { if !$0 { store.message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.message ?? "")
            }
        }
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
