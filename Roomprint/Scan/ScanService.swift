import Foundation
import AVFoundation
import CoreGraphics
import UIKit
@preconcurrency import Vision

// MARK: - Types

/// One frame chosen from the walkthrough video.
struct ScanFrame {
    let index: Int
    let time: Double
    let image: UIImage
    /// JPEG for upload (small).
    let jpeg: Data
    /// Label text the phone read on this frame, if any.
    var text: String = ""
}

/// One belonging the model found.
struct ScanItem: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var brand: String
    var model: String
    var serial: String
    var quantity: Int
    var value: Int
    var confidence: String
    var frame: Int
    var notes: String
}

struct ScanResponse: Codable {
    var items: [ScanItem]
    var model: String?
}

enum ScanError: LocalizedError {
    case noFrames
    case server(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .noFrames: return "No usable frames were found in that video. Hold the phone steady and move slowly."
        case .server(let text): return text
        case .network(let text): return text
        }
    }
}

enum ScanStage: Equatable {
    case reading
    case extracting(done: Int, total: Int)
    case readingLabels(done: Int, total: Int)
    case uploading
    case waiting

    var title: String {
        switch self {
        case .reading: return "Reading the video"
        case .extracting(let d, let t): return "Picking frames \(d)/\(t)"
        case .readingLabels(let d, let t): return "Reading labels \(d)/\(t)"
        case .uploading: return "Sending frames"
        case .waiting: return "Identifying items and values"
        }
    }

    var detail: String {
        switch self {
        case .reading, .extracting: return "Sharp, distinct frames only."
        case .readingLabels: return "Model and serial numbers, on the phone."
        case .uploading: return "Frames are processed and not stored."
        case .waiting: return "Usually under two minutes."
        }
    }
}

// MARK: - Service

enum ScanService {

    // MARK: Frames

    /// Picks sharp, distinct frames from the video, about one per `AppConfig.scanFrameInterval` seconds,
    /// at most `AppConfig.scanMaxFrames`. Longer videos are sampled more sparsely.
    static func extractFrames(from url: URL, progress: @escaping (ScanStage) -> Void) async throws -> [ScanFrame] {
        await MainActor.run { progress(.reading) }
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0.2 else { throw ScanError.noFrames }

        let interval = max(AppConfig.scanFrameInterval, duration / Double(AppConfig.scanMaxFrames))
        var times: [CMTime] = []
        var t = min(0.4, duration / 2)
        while t < duration - 0.05 && times.count < AppConfig.scanMaxFrames {
            times.append(CMTime(seconds: t, preferredTimescale: 600))
            t += interval
        }
        if times.isEmpty { times = [CMTime(seconds: duration / 2, preferredTimescale: 600)] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: AppConfig.scanFrameMaxSide, height: AppConfig.scanFrameMaxSide)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.3, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.3, preferredTimescale: 600)

        var candidates: [(time: Double, image: CGImage, sharpness: Double, signature: [UInt8])] = []
        var done = 0
        for await result in generator.images(for: times) {
            done += 1
            let d = done, total = times.count
            await MainActor.run { progress(.extracting(done: d, total: total)) }
            guard let image = try? result.image else { continue }
            let gray = grayThumb(image, side: 48)
            let sharp = sharpness(gray, side: 48)
            candidates.append((result.requestedTime.seconds, image, sharp, gray))
        }
        guard !candidates.isEmpty else { throw ScanError.noFrames }

        // Drop blurry frames (relative to the video's own typical sharpness) and near-duplicates.
        let sorted = candidates.map(\.sharpness).sorted()
        let median = sorted[sorted.count / 2]
        let minSharp = median * 0.45
        var kept: [ScanFrame] = []
        var lastSignature: [UInt8]?
        for c in candidates {
            if c.sharpness < minSharp && candidates.count > 6 { continue }
            if let last = lastSignature, difference(last, c.signature) < 9 { continue }
            let ui = UIImage(cgImage: c.image)
            guard let jpeg = ui.jpegData(compressionQuality: 0.6) else { continue }
            kept.append(ScanFrame(index: kept.count, time: c.time, image: ui, jpeg: jpeg))
            lastSignature = c.signature
        }
        if kept.isEmpty, let best = candidates.max(by: { $0.sharpness < $1.sharpness }) {
            let ui = UIImage(cgImage: best.image)
            if let jpeg = ui.jpegData(compressionQuality: 0.6) {
                kept = [ScanFrame(index: 0, time: best.time, image: ui, jpeg: jpeg)]
            }
        }
        guard !kept.isEmpty else { throw ScanError.noFrames }
        return kept
    }

    /// Reads printed text (labels, model and serial stickers) on each frame, on the phone.
    static func readLabels(_ frames: [ScanFrame], progress: @escaping (ScanStage) -> Void) async -> [ScanFrame] {
        var out = frames
        for i in frames.indices {
            let d = i + 1, total = frames.count
            await MainActor.run { progress(.readingLabels(done: d, total: total)) }
            guard let cg = frames[i].image.cgImage else { continue }
            out[i].text = await recognizeText(cg)
        }
        return out
    }

    private static func recognizeText(_ image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first }
                    .filter { $0.confidence >= 0.35 }
                    .map { $0.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.count >= 2 }
                continuation.resume(returning: Array(lines.prefix(12)).joined(separator: " | "))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    // MARK: Upload

    /// Sends the frames to the scan service and returns the items it found.
    static func upload(room: String, frames: [ScanFrame], deviceID: String,
                       progress: @escaping (ScanStage) -> Void) async throws -> ScanResponse {
        await MainActor.run { progress(.uploading) }
        // The body is the Claude "messages" array; the service wraps it with the prompt and model.
        var content: [[String: Any]] = []
        content.append(["type": "text",
                        "text": "Room: \(room). \(frames.count) frames follow in time order. Index each frame from 0."])
        for f in frames {
            var label = "Frame \(f.index) at \(String(format: "%.1f", f.time))s."
            if !f.text.isEmpty { label += " OCR text: \(String(f.text.prefix(300)))" }
            content.append(["type": "text", "text": label])
            content.append(["type": "image",
                            "source": ["type": "base64", "media_type": "image/jpeg",
                                       "data": f.jpeg.base64EncodedString()]])
        }
        content.append(["type": "text", "text": "List the items now as the JSON object described."])
        let messages: [[String: Any]] = [["role": "user", "content": content]]
        let body = try JSONSerialization.data(withJSONObject: messages)

        var request = URLRequest(url: AppConfig.scanServiceURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 240
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.scanAppKey, forHTTPHeaderField: "X-Roomprint-Key")
        request.setValue(deviceID, forHTTPHeaderField: "X-Roomprint-Device")
        request.setValue(String(frames.count), forHTTPHeaderField: "X-Roomprint-Frames")
        request.setValue(String(room.prefix(60)).replacingOccurrences(of: "\n", with: " "),
                         forHTTPHeaderField: "X-Roomprint-Room")

        await MainActor.run { progress(.waiting) }
        let session = URLSession(configuration: {
            let c = URLSessionConfiguration.default
            c.timeoutIntervalForRequest = 240
            c.timeoutIntervalForResource = 300
            c.waitsForConnectivity = true
            return c
        }())
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.upload(for: request, from: body)
        } catch {
            throw ScanError.network("Couldn't reach the scan service. Check your connection and try again.")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            if let err = try? JSONDecoder().decode(ServerError.self, from: data), !err.error.isEmpty {
                throw ScanError.server(err.error)
            }
            throw ScanError.server("The scan service returned an error (\(status)). Try again in a minute.")
        }
        do {
            return try JSONDecoder().decode(ScanResponse.self, from: data)
        } catch {
            throw ScanError.server("The scan service sent back something unexpected. Try again.")
        }
    }

    private struct ServerError: Codable { var error: String }

    // MARK: Image math (tiny grayscale thumbnails for sharpness and similarity)

    private static func grayThumb(_ image: CGImage, side: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: side * side)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        pixels.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return pixels
    }

    /// Mean absolute difference between neighbouring pixels: higher = more detail = sharper.
    private static func sharpness(_ g: [UInt8], side: Int) -> Double {
        var total = 0
        var n = 0
        for y in 0..<side {
            for x in 0..<(side - 1) {
                total += abs(Int(g[y * side + x]) - Int(g[y * side + x + 1]))
                n += 1
            }
        }
        for y in 0..<(side - 1) {
            for x in 0..<side {
                total += abs(Int(g[y * side + x]) - Int(g[(y + 1) * side + x]))
                n += 1
            }
        }
        return n == 0 ? 0 : Double(total) / Double(n)
    }

    /// Mean absolute difference between two thumbnails (0 = identical).
    private static func difference(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 255 }
        var total = 0
        for i in a.indices { total += abs(Int(a[i]) - Int(b[i])) }
        return Double(total) / Double(a.count)
    }
}
