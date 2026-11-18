import SwiftUI
import SwiftData
import UIKit

/// Demo mode for App Store screenshots and quick review demos.
///
/// Launch with `-RPDemo` and the app uses an in-memory store (nothing is saved, real records are never
/// touched) filled with a sample home. `-RPScreen <name>` opens a screen on its own:
/// homes, home, room, scan, review, pdf, export, paywall, settings, onboarding.
/// App Store users can't pass launch arguments, so this never shows for them.
enum Demo {
    static let isOn: Bool = ProcessInfo.processInfo.arguments.contains("-RPDemo")

    /// The screen to open. A "-dark" suffix (used for file names of dark-mode screenshots) is ignored.
    static let screen: String = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-RPScreen"), i + 1 < args.count else { return "home" }
        return args[i + 1].replacingOccurrences(of: "-dark", with: "")
    }()

    // MARK: Sample home

    private struct SampleItem {
        let name: String
        var brand = ""
        var model = ""
        var serial = ""
        var quantity = 1
        let value: Double
        var receipt = false
        var notes = ""
        let symbol: String
    }

    private struct SampleRoom {
        let name: String
        let symbol: String
        let items: [SampleItem]
    }

    private static let mainRooms: [SampleRoom] = [
        SampleRoom(name: "Living room", symbol: "sofa.fill", items: [
            SampleItem(name: "65-inch 4K TV", brand: "Samsung", model: "QN65Q80D", serial: "0B4R3CAX500213N",
                       value: 1300, receipt: true, symbol: "tv"),
            SampleItem(name: "Sectional sofa", value: 2400, symbol: "sofa.fill"),
            SampleItem(name: "Recliner", brand: "La-Z-Boy", value: 1100, receipt: true, symbol: "chair.lounge.fill"),
            SampleItem(name: "Sound bar", brand: "Sonos", model: "Arc", value: 900, receipt: true,
                       symbol: "hifispeaker.fill"),
            SampleItem(name: "Game console", brand: "Sony", model: "PlayStation 5", serial: "E92045YH1187",
                       value: 500, symbol: "gamecontroller.fill"),
            SampleItem(name: "Area rug, 8 × 10", value: 650, symbol: "square.grid.3x3.fill"),
            SampleItem(name: "Books, about 80", value: 640, symbol: "books.vertical.fill"),
            SampleItem(name: "Coffee table", value: 450, symbol: "table.furniture.fill"),
            SampleItem(name: "Floor lamp", quantity: 2, value: 180, symbol: "lamp.floor.fill")
        ]),
        SampleRoom(name: "Kitchen", symbol: "refrigerator.fill", items: [
            SampleItem(name: "French-door refrigerator", brand: "LG", model: "LRFXS2503S", serial: "211KRHT2X419",
                       value: 2300, symbol: "refrigerator.fill"),
            SampleItem(name: "Electric range", brand: "GE", model: "JB735", serial: "GT418390D", value: 1150,
                       symbol: "stove.fill"),
            SampleItem(name: "Dishwasher", brand: "Bosch", model: "500 Series", serial: "FD 0412 00123",
                       value: 1050, symbol: "dishwasher.fill"),
            SampleItem(name: "Cookware set, 10 pieces", brand: "All-Clad", model: "D3", value: 800, receipt: true,
                       symbol: "frying.pan.fill"),
            SampleItem(name: "Espresso machine", brand: "Breville", model: "Barista Express", value: 700,
                       receipt: true, symbol: "cup.and.saucer.fill"),
            SampleItem(name: "Stand mixer", brand: "KitchenAid", model: "Artisan", value: 450, receipt: true,
                       symbol: "fork.knife"),
            SampleItem(name: "Dishes and glassware, service for 8", value: 400, symbol: "wineglass.fill"),
            SampleItem(name: "Bar stools", quantity: 3, value: 140, symbol: "chair.fill"),
            SampleItem(name: "Microwave", brand: "Panasonic", model: "NN-SN966S", serial: "6E21070584",
                       value: 280, symbol: "microwave.fill")
        ]),
        SampleRoom(name: "Primary bedroom", symbol: "bed.double.fill", items: [
            SampleItem(name: "Clothing and shoes", value: 4500, notes: "Estimated total", symbol: "tshirt.fill"),
            SampleItem(name: "King bed and mattress", brand: "Tempur-Pedic", value: 3200, receipt: true,
                       symbol: "bed.double.fill"),
            SampleItem(name: "Jewelry", value: 2500, notes: "Get a written appraisal", symbol: "gift.fill"),
            SampleItem(name: "Dresser", value: 900, receipt: true, symbol: "cabinet.fill"),
            SampleItem(name: "Nightstands", quantity: 2, value: 250, symbol: "lamp.table.fill")
        ]),
        SampleRoom(name: "Office", symbol: "desktopcomputer", items: [
            SampleItem(name: "Laptop", brand: "Dell", model: "XPS 14", serial: "7HQ2YX3", value: 1500,
                       receipt: true, symbol: "laptopcomputer"),
            SampleItem(name: "Desk chair", brand: "Herman Miller", model: "Aeron", value: 1400, receipt: true,
                       symbol: "chair.fill"),
            SampleItem(name: "Standing desk", value: 800, receipt: true, symbol: "table.furniture.fill"),
            SampleItem(name: "27-inch monitor", brand: "Dell", model: "U2724D", serial: "CN0F9K3M7441", value: 520,
                       symbol: "display"),
            SampleItem(name: "Printer", brand: "Brother", model: "MFC-L2750DW", serial: "U64281J9N213", value: 300,
                       symbol: "printer.fill")
        ]),
        SampleRoom(name: "Garage", symbol: "car.fill", items: [
            SampleItem(name: "Riding mower", brand: "John Deere", model: "S130", serial: "1GXS130EAPL012345",
                       value: 2600, symbol: "leaf.fill"),
            SampleItem(name: "Bicycles", quantity: 2, value: 700, receipt: true, symbol: "bicycle"),
            SampleItem(name: "Cordless tool set", brand: "DeWalt", model: "20V MAX", value: 650, receipt: true,
                       symbol: "wrench.and.screwdriver.fill"),
            SampleItem(name: "Kayaks", quantity: 2, value: 550, symbol: "water.waves"),
            SampleItem(name: "Chest freezer", brand: "Frigidaire", serial: "WB34T1180", value: 450,
                       symbol: "snowflake"),
            SampleItem(name: "Pressure washer", brand: "Ryobi", value: 400, receipt: true, symbol: "drop.fill")
        ]),
        SampleRoom(name: "Bathroom", symbol: "shower.fill", items: [])
    ]

    private static let lakeRooms: [SampleRoom] = [
        SampleRoom(name: "Great room", symbol: "sofa.fill", items: [
            SampleItem(name: "Sectional sofa", value: 2200, receipt: true, symbol: "sofa.fill"),
            SampleItem(name: "55-inch TV", brand: "Samsung", model: "UN55DU8000", serial: "0D7Y3CBX802114K",
                       value: 700, symbol: "tv"),
            SampleItem(name: "Rocking chairs", quantity: 2, value: 180, symbol: "chair.fill")
        ]),
        SampleRoom(name: "Dock & boat", symbol: "sailboat.fill", items: [
            SampleItem(name: "Paddle boards", quantity: 2, value: 600, receipt: true, symbol: "figure.surfing"),
            SampleItem(name: "Fishing gear", value: 800, symbol: "fish.fill"),
            SampleItem(name: "Life jackets", quantity: 6, value: 60, symbol: "lifepreserver.fill")
        ]),
        SampleRoom(name: "Outdoor & patio", symbol: "tree.fill", items: [
            SampleItem(name: "Patio furniture set", value: 1500, receipt: true, symbol: "chair.lounge.fill"),
            SampleItem(name: "Gas grill", brand: "Weber", model: "Genesis E-325s", serial: "51172381", value: 1000,
                       symbol: "flame.fill")
        ])
    ]

    /// Fills an empty store with the sample homes. Does nothing if any home exists.
    @MainActor
    static func seed(into context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Home>())) ?? 0
        guard existing == 0 else { return }
        let now = Date()
        add(home: "Our House", rooms: mainRooms, created: now.addingTimeInterval(-86400), into: context)
        add(home: "Lake House", rooms: lakeRooms, created: now, into: context)
        try? context.save()
    }

    @MainActor
    private static func add(home name: String, rooms: [SampleRoom], created: Date, into context: ModelContext) {
        let home = Home(name: name, address: "")
        home.createdAt = created
        context.insert(home)
        let now = Date()
        for (order, spec) in rooms.enumerated() {
            let room = Room(name: spec.name, symbol: spec.symbol, order: order)
            context.insert(room)
            room.home = home
            // Rooms list items newest first; make the most valuable one the newest.
            let sorted = spec.items.sorted { $0.value * Double($0.quantity) > $1.value * Double($1.quantity) }
            for (index, sample) in sorted.enumerated() {
                let item = Item()
                item.name = sample.name
                item.brand = sample.brand
                item.modelNumber = sample.model
                item.serial = sample.serial
                item.quantity = sample.quantity
                item.unitValue = sample.value
                item.hasReceipt = sample.receipt
                item.notes = sample.notes
                item.createdAt = now.addingTimeInterval(-Double(index) * 60 - Double(order) * 3600)
                context.insert(item)
                item.room = room
                if let pair = photo(sample.symbol, tone: order).storagePair() {
                    let picture = ItemPhoto(data: pair.data, thumb: pair.thumb, kind: .item)
                    context.insert(picture)
                    picture.item = item
                }
            }
        }
    }

    // MARK: A finished scan (review screen)

    private static let scanSamples: [(SampleItem, String)] = [
        (SampleItem(name: "French-door refrigerator", brand: "LG", model: "LRFXS2503S", serial: "211KRHT2X419",
                    value: 2300, symbol: "refrigerator.fill"), "high"),
        (SampleItem(name: "Electric range", brand: "GE", model: "JB735", value: 1150, symbol: "stove.fill"), "high"),
        (SampleItem(name: "Dishwasher", brand: "Bosch", model: "500 Series", value: 1050,
                    symbol: "dishwasher.fill"), "high"),
        (SampleItem(name: "Cookware set, 10 pieces", brand: "All-Clad", value: 800, symbol: "frying.pan.fill"), "medium"),
        (SampleItem(name: "Espresso machine", brand: "Breville", model: "Barista Express", value: 700,
                    symbol: "cup.and.saucer.fill"), "high"),
        (SampleItem(name: "Stand mixer", brand: "KitchenAid", value: 450, symbol: "fork.knife"), "medium"),
        (SampleItem(name: "Bar stools", quantity: 3, value: 140, symbol: "chair.fill"), "high"),
        (SampleItem(name: "Knife block set", value: 300, symbol: "fork.knife.circle.fill"), "low"),
        (SampleItem(name: "Microwave", brand: "Panasonic", value: 280, symbol: "microwave.fill"), "medium")
    ]

    static func scanItems() -> [ScanItem] {
        scanSamples.enumerated().map { index, pair in
            let (sample, confidence) = pair
            return ScanItem(id: "demo\(index)", name: sample.name, brand: sample.brand, model: sample.model,
                            serial: sample.serial, quantity: sample.quantity, value: Int(sample.value),
                            confidence: confidence, frame: index,
                            notes: confidence == "low" ? "Partly hidden behind the mixer" : "")
        }
    }

    static func scanFrames() -> [ScanFrame] {
        scanSamples.enumerated().compactMap { index, pair in
            guard let jpeg = photo(pair.0.symbol, tone: 1).jpegData(compressionQuality: 0.8) else { return nil }
            return ScanFrame(index: index, time: Double(index) * 1.5, jpeg: jpeg)
        }
    }

    // MARK: Sample photos

    /// A clean product-style tile: the item's symbol on a soft studio gradient.
    static func photo(_ symbol: String, tone: Int) -> UIImage {
        let tones: [(UIColor, UIColor)] = [
            (UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1), UIColor(red: 0.88, green: 0.85, blue: 0.78, alpha: 1)),
            (UIColor(red: 0.93, green: 0.95, blue: 0.97, alpha: 1), UIColor(red: 0.80, green: 0.85, blue: 0.90, alpha: 1)),
            (UIColor(red: 0.97, green: 0.93, blue: 0.91, alpha: 1), UIColor(red: 0.90, green: 0.82, blue: 0.78, alpha: 1)),
            (UIColor(red: 0.93, green: 0.96, blue: 0.93, alpha: 1), UIColor(red: 0.80, green: 0.88, blue: 0.82, alpha: 1))
        ]
        let (top, bottom) = tones[abs(tone) % tones.count]
        let ink = UIColor(red: 22 / 255, green: 38 / 255, blue: 58 / 255, alpha: 0.88)
        let size = CGSize(width: 640, height: 640)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: [top.cgColor, bottom.cgColor] as CFArray,
                                         locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            let config = UIImage.SymbolConfiguration(pointSize: 250, weight: .regular)
            if let glyph = UIImage(systemName: symbol, withConfiguration: config)?
                .withTintColor(ink, renderingMode: .alwaysOriginal) {
                let fit = min(380 / glyph.size.width, 380 / glyph.size.height, 1.6)
                let drawn = CGSize(width: glyph.size.width * fit, height: glyph.size.height * fit)
                glyph.draw(in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2,
                                      width: drawn.width, height: drawn.height))
            }
        }
    }
}

/// A URL that can drive `.sheet(item:)`.
struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
