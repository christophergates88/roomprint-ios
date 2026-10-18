import SwiftUI
import SwiftData
import LocalAuthentication

@main
struct RoomprintApp: App {
    @State private var store = ProStore()
    @State private var scans = ScanStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(scans)
                .fontDesign(.rounded)
        }
        .modelContainer(for: [Home.self, Room.self, Item.self, ItemPhoto.self])
    }
}

/// Decides between onboarding, the Face ID lock screen and the app itself.
struct RootView: View {
    @AppStorage("didOnboard") private var didOnboard = false
    @AppStorage("lockEnabled") private var lockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var locked = true

    var body: some View {
        Group {
            if !didOnboard {
                OnboardingView { didOnboard = true }
            } else if lockEnabled && locked {
                LockView { locked = false }
            } else {
                HomesView()
            }
        }
        .onAppear {
            if !lockEnabled { locked = false }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { locked = lockEnabled }
        }
    }
}

struct LockView: View {
    var onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            LogoMark(size: 88)
            Text("Roomprint is locked")
                .font(.title2.bold())
            Text("Your home records are protected.")
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                unlock()
            } label: {
                Label("Unlock", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.rpGround)
        .onAppear(perform: unlock)
    }

    private func unlock() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode set on the device, so there is nothing to check against.
            onUnlock()
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your home records") { success, _ in
            if success {
                DispatchQueue.main.async { onUnlock() }
            }
        }
    }
}
