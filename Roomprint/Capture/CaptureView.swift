import SwiftUI
import AVFoundation
import PhotosUI
import UIKit

enum CaptureMode {
    /// Take one photo, then close.
    case single
    /// Keep shooting; each photo becomes a new item.
    case multi
}

/// Full-screen camera with a big shutter. In multi mode it stays open so you can
/// photograph items one after another.
struct CaptureView: View {
    let title: String
    let mode: CaptureMode
    /// Called for every photo. Return false to close the camera.
    let onCapture: (UIImage) -> Bool

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()
    @State private var count = 0
    @State private var lastThumb: UIImage?
    @State private var flash = false
    @State private var libraryItems: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isAvailable && camera.authorized {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            } else {
                unavailableView
            }

            Color.white
                .opacity(flash ? 0.55 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                topBar
                Spacer()
                if mode == .multi && count == 0 && camera.isAvailable && camera.authorized {
                    Text("Snap one item at a time")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 12)
                }
                bottomBar
            }
            .foregroundStyle(.white)
        }
        .statusBarHidden()
        .onAppear {
            camera.onPhoto = { image in handle(image) }
            camera.start()
        }
        .onDisappear { camera.stop() }
        .onChange(of: libraryItems) { _, picked in
            importFromLibrary(picked)
        }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text(mode == .multi ? "Done" : "Cancel")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            Spacer()
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Text(count == 1 ? "1 saved" : "\(count) saved")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .opacity(mode == .multi ? 1 : 0)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        HStack {
            Group {
                if let lastThumb {
                    Image(uiImage: lastThumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.white.opacity(0.12)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer()

            Button(action: shoot) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 5)
                        .frame(width: 84, height: 84)
                    Circle()
                        .fill(Color.rpRecord)
                        .frame(width: 64, height: 64)
                        .scaleEffect(camera.isCapturing ? 0.85 : 1)
                }
            }
            .disabled(!(camera.isAvailable && camera.authorized) || camera.isCapturing)
            .accessibilityLabel("Take photo")

            Spacer()

            PhotosPicker(selection: $libraryItems,
                         maxSelectionCount: mode == .multi ? 20 : 1,
                         matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .accessibilityLabel("Choose from library")
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }

    private var unavailableView: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
            if camera.isAvailable {
                Text("Camera access is off")
                    .font(.title3.bold())
                Text("Turn on camera access for Roomprint in Settings, or choose photos from your library.")
                    .multilineTextAlignment(.center)
                    .opacity(0.8)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("No camera here")
                    .font(.title3.bold())
                Text("Choose photos from your library with the button below.")
                    .multilineTextAlignment(.center)
                    .opacity(0.8)
            }
        }
        .foregroundStyle(.white)
        .padding(32)
    }

    // MARK: Actions

    private func shoot() {
        Haptics.tap()
        camera.capture()
    }

    private func handle(_ image: UIImage) {
        let keepGoing = onCapture(image)
        count += 1
        lastThumb = image.resized(maxSide: 200)
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        withAnimation(.easeIn(duration: 0.25).delay(0.08)) { flash = false }
        if mode == .single || !keepGoing {
            dismiss()
        }
    }

    private func importFromLibrary(_ picked: [PhotosPickerItem]) {
        guard !picked.isEmpty else { return }
        Task {
            for entry in picked {
                guard let data = try? await entry.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { continue }
                let keepGoing = onCapture(image)
                count += 1
                lastThumb = image.resized(maxSide: 200)
                if mode == .single || !keepGoing {
                    dismiss()
                    return
                }
            }
            libraryItems = []
        }
    }
}

// MARK: - Camera engine

final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    let isAvailable: Bool
    @Published var authorized = true
    @Published var isCapturing = false
    var onPhoto: ((UIImage) -> Void)?

    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "roomprint.camera")
    private var configured = false

    override init() {
        isAvailable = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
        super.init()
    }

    func start() {
        guard isAvailable else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorized = true
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.authorized = granted
                    if granted { self.configureAndRun() }
                }
            }
        default:
            authorized = false
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        queue.async {
            // The app runs in portrait, so save photos upright.
            if let connection = self.output.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            let settings = AVCapturePhotoSettings()
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureAndRun() {
        queue.async {
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                self.session.commitConfiguration()
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        DispatchQueue.main.async {
            self.isCapturing = false
            if let image { self.onPhoto?(image) }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
