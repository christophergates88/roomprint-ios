import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// The AI room scan: film a walkthrough (or pick a video), the phone pulls frames and reads labels,
/// the scan service names and values the items, and you approve the list.
struct ScanView: View {
    @Bindable var room: Room
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ScanStore.self) private var scans

    private enum Phase: Equatable {
        case start
        case working(ScanStage)
        case review
        case failed(String)
    }

    @State private var phase: Phase = .start
    @State private var recording = false
    @State private var pickedVideo: PhotosPickerItem?
    @State private var frames: [ScanFrame] = []
    @State private var items: [ScanItem] = []
    @State private var workTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .start:
                    startScreen
                case .working(let stage):
                    workingScreen(stage)
                case .review:
                    ScanReviewView(room: room, frames: frames, items: $items, onApprove: approve, onRescan: reset)
                case .failed(let text):
                    failedScreen(text)
                }
            }
            .background(Color.rpGround)
            .navigationTitle(phase == .review ? "Review \(room.name)" : "Scan \(room.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(phase == .review ? "Discard" : "Cancel") {
                        workTask?.cancel()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
        // The upload runs in the foreground, so keep the screen awake until the list is back.
        .onChange(of: isWorking, initial: true) { _, working in
            UIApplication.shared.isIdleTimerDisabled = working
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .fullScreenCover(isPresented: $recording) {
            VideoRecorder { url in
                recording = false
                if let url { start(with: url) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickedVideo) { _, item in
            guard let item else { return }
            pickedVideo = nil
            phase = .working(.reading)
            workTask = Task {
                do {
                    guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                        throw ScanError.noFrames
                    }
                    start(with: movie.url)
                } catch {
                    phase = .failed("That video couldn't be opened. Try another one or record a new walkthrough.")
                }
            }
        }
    }

    private var isWorking: Bool {
        if case .working = phase { return true }
        return false
    }

    // MARK: Screens

    private var startScreen: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "video.badge.waveform.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(Color.rpRecordDeep)
                    .padding(.top, 24)
                Text("Film the room once.\nWe list what's in it.")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 14) {
                    tip("figure.walk", "Walk slowly around the room, phone held steady, so everything gets a clear look.")
                    tip("tag.fill", "Pause a second on the label of anything expensive — the model or serial number gets read.")
                    tip("checkmark.circle.fill", "You review the list before anything is saved. Swipe off mistakes, tap to fix a value.")
                    tip("clock", "30 seconds to 3 minutes is plenty. Frames are processed, never stored.")
                }
                .card()

                Text(scans.balanceLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    recording = true
                } label: {
                    Label("Record a walkthrough", systemImage: "record.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.rpRecordDeep)
                .controlSize(.large)

                PhotosPicker(selection: $pickedVideo, matching: .videos) {
                    Label("Choose a video", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
            .background(.bar)
        }
    }

    private func workingScreen(_ stage: ScanStage) -> some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text(stage.title)
                .font(.title3.bold())
            Text(stage.detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if case .waiting = stage {
                Text("Keep Roomprint open. The screen stays awake until the list is back.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedScreen(_ text: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Scan didn't finish")
                .font(.title3.bold())
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
            Button("Try again") { reset() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            Text(text).font(.subheadline)
        }
    }

    // MARK: Work

    private func start(with url: URL) {
        workTask?.cancel()
        phase = .working(.reading)
        let roomName = room.name
        let device = scans.deviceID
        workTask = Task {
            do {
                let picked = try await ScanService.extractFrames(from: url) { stage in phase = .working(stage) }
                try Task.checkCancellation()
                let labeled = await ScanService.readLabels(picked) { stage in phase = .working(stage) }
                try Task.checkCancellation()
                let response = try await ScanService.upload(room: roomName, frames: labeled, deviceID: device) { stage in
                    phase = .working(stage)
                }
                try Task.checkCancellation()
                frames = labeled
                items = response.items
                if items.isEmpty {
                    phase = .failed("Nothing recognizable was found in that video. Try again with more light, moving slowly.")
                } else {
                    Haptics.success()
                    phase = .review
                }
            } catch is CancellationError {
                // dismissed
            } catch {
                phase = .failed(error.localizedDescription)
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func reset() {
        workTask?.cancel()
        frames = []
        items = []
        phase = .start
    }

    /// Saves the approved items into the room, with the best frame as each item's photo.
    private func approve() {
        for scanItem in items {
            let item = Item()
            item.name = scanItem.name
            item.brand = scanItem.brand
            item.modelNumber = scanItem.model
            item.serial = scanItem.serial
            item.quantity = max(1, scanItem.quantity)
            item.unitValue = Double(max(0, scanItem.value))
            var notes: [String] = []
            if !scanItem.notes.isEmpty { notes.append(scanItem.notes) }
            if scanItem.confidence == "low" { notes.append("AI scan: low confidence, please check.") }
            item.notes = notes.joined(separator: " ")
            context.insert(item)
            item.room = room
            let frameIndex = min(max(0, scanItem.frame), max(0, frames.count - 1))
            if frames.indices.contains(frameIndex), let pair = frames[frameIndex].image.storagePair() {
                let photo = ItemPhoto(data: pair.data, thumb: pair.thumb, kind: .item)
                context.insert(photo)
                photo.item = item
            }
        }
        scans.consumeScan()
        Haptics.success()
        dismiss()
    }
}

// MARK: - Video recorder (system camera, video mode)

struct VideoRecorder: UIViewControllerRepresentable {
    let onFinish: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.mediaTypes = [UTType.movie.identifier]
            picker.cameraCaptureMode = .video
            picker.videoQuality = .typeHigh
            picker.videoMaximumDuration = 240
            picker.cameraDevice = .rear
        } else {
            picker.sourceType = .photoLibrary
            picker.mediaTypes = [UTType.movie.identifier]
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (URL?) -> Void
        init(onFinish: @escaping (URL?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let url = info[.mediaURL] as? URL
            onFinish(url)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

// MARK: - A video chosen from Photos, copied to a temp file

struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("scan-\(UUID().uuidString)")
                .appendingPathExtension(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(url: dest)
        }
    }
}
