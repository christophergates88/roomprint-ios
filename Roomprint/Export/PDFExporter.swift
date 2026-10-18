import Foundation
import UIKit
import PDFKit

// MARK: - Plain snapshot of a home, safe to render off the main thread

struct ReportItem {
    let name: String
    let brand: String
    let model: String
    let serial: String
    let quantity: Int
    let unitValue: Double
    let total: Double
    let purchasePrice: Double?
    let purchaseDate: Date?
    let hasReceipt: Bool
    let hasProof: Bool
    let needsDetails: Bool
    let notes: String
    let thumb: Data?
}

struct ReportRoom {
    let name: String
    let items: [ReportItem]
    var total: Double { items.reduce(0) { $0 + $1.total } }
    var count: Int { items.reduce(0) { $0 + $1.quantity } }
}

struct ReportData {
    let homeName: String
    let address: String
    let createdOn: Date
    let rooms: [ReportRoom]
    let currencyCode: String

    var total: Double { rooms.reduce(0) { $0 + $1.total } }
    var itemCount: Int { rooms.reduce(0) { $0 + $1.count } }
    var needsProof: Int { rooms.flatMap { $0.items }.filter { !$0.hasProof }.count }
    var needsDetails: Int { rooms.flatMap { $0.items }.filter { $0.needsDetails }.count }

    @MainActor
    init(home: Home, includePhotos: Bool) {
        homeName = home.name
        address = home.address
        createdOn = Date()
        currencyCode = Money.code
        rooms = home.sortedRooms.compactMap { room -> ReportRoom? in
            let items = room.items
                .sorted { $0.createdAt < $1.createdAt }
                .map { item in
                    ReportItem(
                        name: item.displayName,
                        brand: item.brand,
                        model: item.modelNumber,
                        serial: item.serial,
                        quantity: item.quantity,
                        unitValue: item.unitValue,
                        total: item.totalValue,
                        purchasePrice: item.purchasePrice,
                        purchaseDate: item.purchaseDate,
                        hasReceipt: item.hasReceipt,
                        hasProof: item.hasProof,
                        needsDetails: item.needsDetails,
                        notes: item.notes,
                        thumb: includePhotos ? item.coverThumb : nil)
                }
            return items.isEmpty ? nil : ReportRoom(name: room.name, items: items)
        }
    }

    func money(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
    }
}

enum ExportError: LocalizedError {
    case writeFailed
    var errorDescription: String? { "The file couldn't be saved. Please try again." }
}

// MARK: - PDF and CSV

enum PDFExporter {
    private static let page = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
    private static let margin: CGFloat = 44
    private static let navy = UIColor(red: 22 / 255, green: 38 / 255, blue: 58 / 255, alpha: 1)
    private static let vellum = UIColor(red: 243 / 255, green: 238 / 255, blue: 226 / 255, alpha: 1)
    private static let record = UIColor(red: 229 / 255, green: 83 / 255, blue: 61 / 255, alpha: 1)
    private static let ink = UIColor(red: 22 / 255, green: 38 / 255, blue: 58 / 255, alpha: 1)
    private static let muted = UIColor(red: 93 / 255, green: 106 / 255, blue: 121 / 255, alpha: 1)
    private static let rule = UIColor(red: 221 / 255, green: 216 / 255, blue: 206 / 255, alpha: 1)
    private static let good = UIColor(red: 47 / 255, green: 125 / 255, blue: 91 / 255, alpha: 1)
    private static let warn = UIColor(red: 168 / 255, green: 110 / 255, blue: 20 / 255, alpha: 1)

    static func fileName(for report: ReportData, ext: String) -> String {
        let safe = report.homeName
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")
        return "\(safe) Home Record.\(ext)"
    }

    static func writePDF(_ report: ReportData, password: String?) throws -> URL {
        let data = render(report)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(for: report, ext: "pdf"))
        try? FileManager.default.removeItem(at: url)
        if let password, !password.isEmpty {
            guard let document = PDFDocument(data: data),
                  document.write(to: url, withOptions: [.userPasswordOption: password, .ownerPasswordOption: password])
            else { throw ExportError.writeFailed }
        } else {
            try data.write(to: url, options: .atomic)
        }
        return url
    }

    static func writeCSV(_ report: ReportData) throws -> URL {
        func field(_ value: String) -> String {
            "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var lines = ["Room,Item,Brand,Model,Serial number,Quantity,Replacement value each,Replacement value total,Price paid,Purchase date,Receipt,Notes"]
        for room in report.rooms {
            for item in room.items {
                let row: [String] = [
                    field(room.name), field(item.name), field(item.brand), field(item.model), field(item.serial),
                    String(item.quantity),
                    String(format: "%.2f", item.unitValue),
                    String(format: "%.2f", item.total),
                    item.purchasePrice.map { String(format: "%.2f", $0) } ?? "",
                    item.purchaseDate.map { dateFormatter.string(from: $0) } ?? "",
                    item.hasReceipt ? "Yes" : "No",
                    field(item.notes)
                ]
                lines.append(row.joined(separator: ","))
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(for: report, ext: "csv"))
        try? FileManager.default.removeItem(at: url)
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: Rendering

    static func render(_ report: ReportData) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "\(report.homeName) Home Record",
            kCGPDFContextCreator as String: "Roomprint"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)
        let width = page.width - margin * 2
        let bottomLimit = page.height - 64

        return renderer.pdfData { context in
            var y: CGFloat = 0
            var pageNumber = 0

            func newPage() {
                context.beginPage()
                pageNumber += 1
                drawFooter(page: pageNumber, report: report)
                if pageNumber > 1 {
                    drawLogo(at: CGPoint(x: margin, y: 30), size: 18)
                    text(report.homeName, .boldSystemFont(ofSize: 9), ink,
                         in: CGRect(x: margin + 26, y: 34, width: 300, height: 14))
                    fill(CGRect(x: margin, y: 56, width: width, height: 0.6), rule)
                    y = 72
                }
            }

            func ensure(_ height: CGFloat) {
                if y + height > bottomLimit { newPage() }
            }

            // Page 1 header band
            newPage()
            fill(CGRect(x: 0, y: 0, width: page.width, height: 150), navy)
            drawLogo(at: CGPoint(x: margin, y: 34), size: 30)
            text("ROOMPRINT HOME RECORD", .boldSystemFont(ofSize: 9), vellum.withAlphaComponent(0.8),
                 in: CGRect(x: margin + 40, y: 44, width: 300, height: 14))
            text(report.homeName, .boldSystemFont(ofSize: 26), vellum,
                 in: CGRect(x: margin, y: 78, width: width, height: 32))
            let dateText = report.createdOn.formatted(date: .long, time: .omitted)
            let sub = [report.address, "Created \(dateText)"].filter { !$0.isEmpty }.joined(separator: "   ·   ")
            text(sub, .systemFont(ofSize: 10), vellum.withAlphaComponent(0.8),
                 in: CGRect(x: margin, y: 114, width: width, height: 16))
            y = 172

            // Summary boxes
            let boxW = (width - 20) / 3
            let boxes: [(String, String, String)] = [
                ("ESTIMATED REPLACEMENT VALUE", report.money(report.total), "Contents only"),
                ("ITEMS", "\(report.itemCount)", "\(report.rooms.count) rooms"),
                ("NEED PROOF", "\(report.needsProof)", "No serial or receipt")
            ]
            for (index, box) in boxes.enumerated() {
                let x = margin + CGFloat(index) * (boxW + 10)
                let rect = CGRect(x: x, y: y, width: boxW, height: 74)
                stroke(rect, rule)
                text(box.0, .systemFont(ofSize: 7.5), muted, in: CGRect(x: x + 10, y: y + 10, width: boxW - 20, height: 12))
                text(box.1, .boldSystemFont(ofSize: index == 0 ? 20 : 18), ink,
                     in: CGRect(x: x + 10, y: y + 24, width: boxW - 20, height: 26))
                text(box.2, .systemFont(ofSize: 8.5), muted, in: CGRect(x: x + 10, y: y + 52, width: boxW - 20, height: 12))
            }
            y += 96

            // Value by room
            text("Value by room", .boldSystemFont(ofSize: 15), ink, in: CGRect(x: margin, y: y, width: width, height: 20))
            y += 26
            for room in report.rooms.sorted(by: { $0.total > $1.total }) {
                ensure(22)
                text(room.name, .systemFont(ofSize: 10), ink, in: CGRect(x: margin, y: y, width: width * 0.6, height: 14))
                text("\(room.count)", .systemFont(ofSize: 10), ink,
                     in: CGRect(x: margin + width * 0.6, y: y, width: width * 0.15, height: 14), align: .right)
                text(report.money(room.total), .systemFont(ofSize: 10), ink,
                     in: CGRect(x: margin + width * 0.75, y: y, width: width * 0.25, height: 14), align: .right)
                y += 18
                fill(CGRect(x: margin, y: y - 4, width: width, height: 0.5), rule)
            }
            ensure(22)
            fill(CGRect(x: margin, y: y - 4, width: width, height: 1.2), ink)
            text("Total", .boldSystemFont(ofSize: 10), ink, in: CGRect(x: margin, y: y + 2, width: width * 0.6, height: 14))
            text("\(report.itemCount)", .boldSystemFont(ofSize: 10), ink,
                 in: CGRect(x: margin + width * 0.6, y: y + 2, width: width * 0.15, height: 14), align: .right)
            text(report.money(report.total), .boldSystemFont(ofSize: 10), ink,
                 in: CGRect(x: margin + width * 0.75, y: y + 2, width: width * 0.25, height: 14), align: .right)
            y += 34

            // To finish
            var todos: [String] = []
            if report.needsProof > 0 {
                todos.append("\(report.needsProof) entries have no serial number or receipt. Add proof for your most valuable items first.")
            }
            if report.needsDetails > 0 {
                todos.append("\(report.needsDetails) items still need a name or value.")
            }
            todos.append("Ask your insurance agent whether jewelry, firearms or collectibles should be listed separately on your policy.")
            ensure(40)
            text("To finish this record", .boldSystemFont(ofSize: 15), ink, in: CGRect(x: margin, y: y, width: width, height: 20))
            y += 26
            for todo in todos {
                let height = measure(todo, .systemFont(ofSize: 10), width: width - 16)
                ensure(height + 6)
                text("•", .systemFont(ofSize: 10), ink, in: CGRect(x: margin, y: y, width: 10, height: 14))
                text(todo, .systemFont(ofSize: 10), ink, in: CGRect(x: margin + 16, y: y, width: width - 16, height: height))
                y += height + 6
            }
            y += 16

            // Rooms
            let hasPhotos = report.rooms.contains { $0.items.contains { $0.thumb != nil } }
            let photoW: CGFloat = hasPhotos ? 62 : 0
            let valueW: CGFloat = 80
            let textX = margin + (hasPhotos ? photoW + 12 : 0)
            let textW = width - (textX - margin) - valueW - 10

            for room in report.rooms {
                ensure(90)
                y += 6
                text(room.name, .boldSystemFont(ofSize: 15), ink, in: CGRect(x: margin, y: y, width: width - 120, height: 20))
                text(report.money(room.total), .boldSystemFont(ofSize: 11), muted,
                     in: CGRect(x: margin + width - 120, y: y + 3, width: 120, height: 16), align: .right)
                y += 24
                fill(CGRect(x: margin, y: y, width: width, height: 1.2), ink)
                y += 8

                for item in room.items {
                    let nameText = item.quantity > 1 ? "\(item.name)  ×\(item.quantity)" : item.name
                    let detailParts = [item.brand, item.model].filter { !$0.isEmpty }
                    var detail = detailParts.joined(separator: " ")
                    if !item.serial.isEmpty { detail += detail.isEmpty ? "SN \(item.serial)" : "  ·  SN \(item.serial)" }
                    var status = item.hasProof ? (item.serial.isEmpty ? "Receipt or record" : "Serial recorded") : "Needs proof"
                    if item.needsDetails { status = "Needs details" }
                    if let paid = item.purchasePrice, paid > 0 { status += "  ·  Paid \(report.money(paid))" }
                    if let date = item.purchaseDate { status += "  ·  Bought \(date.formatted(date: .abbreviated, time: .omitted))" }

                    let nameH = measure(nameText, .boldSystemFont(ofSize: 10.5), width: textW)
                    let detailH = detail.isEmpty ? 0 : measure(detail, .systemFont(ofSize: 8.5), width: textW) + 2
                    let notesH = item.notes.isEmpty ? 0 : measure(item.notes, .italicSystemFont(ofSize: 8.5), width: textW) + 2
                    let statusH: CGFloat = 13
                    let textH = nameH + detailH + notesH + statusH + 2
                    let rowH = max(hasPhotos ? photoW : 0, textH) + 12
                    ensure(rowH)

                    if hasPhotos {
                        let box = CGRect(x: margin, y: y, width: photoW, height: photoW)
                        if let data = item.thumb, let image = UIImage(data: data) {
                            drawImage(image, filling: box)
                        } else {
                            fill(box, UIColor(white: 0.94, alpha: 1))
                        }
                    }
                    var ty = y
                    text(nameText, .boldSystemFont(ofSize: 10.5), ink, in: CGRect(x: textX, y: ty, width: textW, height: nameH))
                    ty += nameH + 2
                    if !detail.isEmpty {
                        text(detail, .systemFont(ofSize: 8.5), muted, in: CGRect(x: textX, y: ty, width: textW, height: detailH))
                        ty += detailH
                    }
                    if !item.notes.isEmpty {
                        text(item.notes, .italicSystemFont(ofSize: 8.5), muted, in: CGRect(x: textX, y: ty, width: textW, height: notesH))
                        ty += notesH
                    }
                    let statusColor = item.needsDetails ? warn : (item.hasProof ? good : warn)
                    text(status, .systemFont(ofSize: 8), statusColor, in: CGRect(x: textX, y: ty, width: textW, height: statusH))

                    text(report.money(item.total), .boldSystemFont(ofSize: 10.5), ink,
                         in: CGRect(x: margin + width - valueW, y: y, width: valueW, height: 14), align: .right)
                    if item.quantity > 1 {
                        text("\(report.money(item.unitValue)) each", .systemFont(ofSize: 8), muted,
                             in: CGRect(x: margin + width - valueW, y: y + 15, width: valueW, height: 12), align: .right)
                    }
                    y += rowH
                    fill(CGRect(x: margin, y: y - 6, width: width, height: 0.5), rule)
                }
                y += 14
            }

            // About
            let about = [
                "Values are replacement-cost estimates entered by the homeowner. They are not appraisals and don't guarantee any claim payment.",
                "Keep a copy outside your home, such as in email or cloud storage, and update this record after big purchases."
            ]
            ensure(80)
            text("About this record", .boldSystemFont(ofSize: 13), ink, in: CGRect(x: margin, y: y, width: width, height: 18))
            y += 22
            for line in about {
                let height = measure(line, .systemFont(ofSize: 9), width: width)
                ensure(height + 4)
                text(line, .systemFont(ofSize: 9), muted, in: CGRect(x: margin, y: y, width: width, height: height))
                y += height + 4
            }
        }
    }

    // MARK: Drawing helpers

    private static func attributes(_ font: UIFont, _ color: UIColor, align: NSTextAlignment) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineBreakMode = .byWordWrapping
        return [.font: font, .foregroundColor: color, .paragraphStyle: style]
    }

    private static func measure(_ string: String, _ font: UIFont, width: CGFloat) -> CGFloat {
        let attributed = NSAttributedString(string: string, attributes: attributes(font, .black, align: .left))
        let bounds = attributed.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                             options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return ceil(bounds.height)
    }

    private static func text(_ string: String, _ font: UIFont, _ color: UIColor, in rect: CGRect,
                             align: NSTextAlignment = .left) {
        let attributed = NSAttributedString(string: string, attributes: attributes(font, color, align: align))
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    private static func fill(_ rect: CGRect, _ color: UIColor) {
        color.setFill()
        UIBezierPath(rect: rect).fill()
    }

    private static func stroke(_ rect: CGRect, _ color: UIColor) {
        color.setStroke()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 6)
        path.lineWidth = 0.8
        path.stroke()
    }

    private static func drawImage(_ image: UIImage, filling box: CGRect) {
        guard image.size.width > 0, image.size.height > 0,
              let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        UIBezierPath(roundedRect: box, cornerRadius: 6).addClip()
        let scale = max(box.width / image.size.width, box.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: box.midX - size.width / 2, y: box.midY - size.height / 2)
        image.draw(in: CGRect(origin: origin, size: size))
        cg.restoreGState()
    }

    private static func drawLogo(at origin: CGPoint, size: CGFloat) {
        let k = size / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * k, y: origin.y + y * k) }

        navy.setFill()
        UIBezierPath(roundedRect: CGRect(origin: origin, size: CGSize(width: size, height: size)),
                     cornerRadius: 14 * k).fill()

        let house = UIBezierPath()
        house.move(to: p(12, 29))
        house.addLine(to: p(32, 13))
        house.addLine(to: p(52, 29))
        house.addLine(to: p(52, 51))
        house.addLine(to: p(12, 51))
        house.close()
        house.lineWidth = 4.5 * k
        house.lineJoinStyle = .round
        vellum.setStroke()
        house.stroke()

        let corners = UIBezierPath()
        let segments: [[(CGFloat, CGFloat)]] = [
            [(21, 34), (21, 31), (24, 31)],
            [(43, 34), (43, 31), (40, 31)],
            [(21, 41), (21, 44), (24, 44)],
            [(43, 41), (43, 44), (40, 44)]
        ]
        for segment in segments {
            guard let first = segment.first else { continue }
            corners.move(to: p(first.0, first.1))
            for point in segment.dropFirst() { corners.addLine(to: p(point.0, point.1)) }
        }
        corners.lineWidth = 2.6 * k
        corners.lineCapStyle = .round
        corners.lineJoinStyle = .round
        corners.stroke()

        record.setFill()
        UIBezierPath(ovalIn: CGRect(x: origin.x + (32 - 3.6) * k, y: origin.y + (37.5 - 3.6) * k,
                                    width: 7.2 * k, height: 7.2 * k)).fill()
    }

    private static func drawFooter(page number: Int, report: ReportData) {
        let y = page.height - 40
        text("Private home record for \(report.homeName). Values are estimates, not appraisals.",
             .systemFont(ofSize: 7.5), muted, in: CGRect(x: margin, y: y, width: 400, height: 12))
        text("Page \(number)", .systemFont(ofSize: 7.5), muted,
             in: CGRect(x: page.width - margin - 100, y: y, width: 100, height: 12), align: .right)
    }
}
