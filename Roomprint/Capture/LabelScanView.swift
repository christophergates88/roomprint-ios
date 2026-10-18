import SwiftUI
import PhotosUI
import Vision
import UIKit

enum ScanField: CaseIterable {
    case name, brand, model, serial

    var title: String {
        switch self {
        case .name: return "Name"
        case .brand: return "Brand"
        case .model: return "Model"
        case .serial: return "Serial number"
        }
    }
}

/// Reads the text on a product label (on the phone, no internet) and lets you
/// drop each line into the right field.
struct LabelScanView: View {
    var onAssign: (ScanField, String) -> Void
    var onLabelPhoto: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var lines: [String] = []
    @State private var working = false
    @State private var scanned = false
    @State private var showCamera = false
    @State private var picked: PhotosPickerItem?
    @State private var assigned: [String: ScanField] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if working {
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("Reading the label…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if scanned {
                    results
                } else {
                    intro
                }
            }
            .background(Color.rpGround)
            .navigationTitle("Scan a label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CaptureView(title: "Label", mode: .single) { image in
                    process(image)
                    return false
                }
            }
            .onChange(of: picked) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        process(image)
                    }
                    picked = nil
                }
            }
        }
    }

    private var intro: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "text.viewfinder")
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("Photograph the sticker")
                .font(.title2.bold())
            Text("Look on the back or bottom for the model and serial number. Get close, with good light.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Take a photo", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                PhotosPicker(selection: $picked, matching: .images) {
                    Label("Choose a photo", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var results: some View {
        List {
            if lines.isEmpty {
                Section {
                    Text("No text found. Try again closer to the label, with more light.")
                        .foregroundStyle(.secondary)
                    Button("Try again") { reset() }
                }
            } else {
                Section {
                    ForEach(lines, id: \.self) { line in
                        Menu {
                            ForEach(ScanField.allCases, id: \.self) { field in
                                Button("Use as \(field.title)") {
                                    let value = LabelText.clean(line)
                                    // A line lives in one field: moving it clears the field it came from,
                                    // and a line that previously held the target field loses its mark.
                                    if let previous = assigned[line], previous != field {
                                        onAssign(previous, "")
                                    }
                                    for (other, held) in assigned where held == field && other != line {
                                        assigned[other] = nil
                                    }
                                    onAssign(field, value)
                                    assigned[line] = field
                                    Haptics.tap()
                                }
                            }
                        } label: {
                            HStack {
                                Text(line)
                                    .font(.body.monospaced())
                                    .foregroundStyle(Color.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if let field = assigned[line] {
                                    Label(field.title, systemImage: "checkmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.green)
                                } else if let guess = LabelText.guess(line) {
                                    Text(guess.title + "?")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Tap a line to use it")
                } footer: {
                    Text("The label photo is saved with the item.")
                }
                Section {
                    Button("Scan another label") { reset() }
                }
            }
        }
    }

    private func reset() {
        lines = []
        assigned = [:]
        scanned = false
    }

    private func process(_ image: UIImage) {
        onLabelPhoto(image)
        working = true
        Task {
            let found = await TextRecognizer.lines(in: image)
            lines = found
            working = false
            scanned = true
        }
    }
}

/// On-device text recognition using Apple's Vision framework.
enum TextRecognizer {
    static func lines(in image: UIImage) async -> [String] {
        let upright = image.resized(maxSide: 2400)
        guard let cgImage = upright.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
                try? handler.perform([request])
                let observations = request.results ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.count >= 2 }
                var seen = Set<String>()
                let unique = text.filter { seen.insert($0).inserted }
                continuation.resume(returning: unique)
            }
        }
    }
}

/// Helpers to tidy label text like "S/N: AB123" into "AB123".
enum LabelText {
    private static let prefix = try? NSRegularExpression(
        pattern: "^(serial\\s*(no\\.?|number|#)?|s/?n|model\\s*(no\\.?|number|#)?|m/?n|mod\\.?|p/?n|part\\s*(no\\.?|number))\\s*[:#.\\-]?\\s*",
        options: [.caseInsensitive])

    static func clean(_ line: String) -> String {
        guard let prefix else { return line }
        let range = NSRange(line.startIndex..., in: line)
        let stripped = prefix.stringByReplacingMatches(in: line, range: range, withTemplate: "")
        let result = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? line : result
    }

    static func guess(_ line: String) -> ScanField? {
        let lower = line.lowercased()
        if lower.hasPrefix("serial") || lower.hasPrefix("s/n") || lower.hasPrefix("sn ") || lower.hasPrefix("sn:") {
            return .serial
        }
        if lower.hasPrefix("model") || lower.hasPrefix("m/n") || lower.hasPrefix("mod.") || lower.hasPrefix("mod ") {
            return .model
        }
        return nil
    }
}
