import Foundation
import SwiftData
import UIKit

@Model
final class Home {
    var name: String
    var address: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Room.home)
    var rooms: [Room] = []

    init(name: String, address: String = "") {
        self.name = name
        self.address = address
        self.createdAt = Date()
    }
}

@Model
final class Room {
    var name: String
    var symbol: String
    var order: Int
    var createdAt: Date
    var home: Home?
    @Relationship(deleteRule: .cascade, inverse: \Item.room)
    var items: [Item] = []

    init(name: String, symbol: String, order: Int) {
        self.name = name
        self.symbol = symbol
        self.order = order
        self.createdAt = Date()
    }
}

@Model
final class Item {
    var name: String
    var brand: String
    var modelNumber: String
    var serial: String
    var quantity: Int
    /// Replacement value for one unit, in the user's currency.
    var unitValue: Double
    var purchasePrice: Double?
    var purchaseDate: Date?
    var hasReceipt: Bool
    var notes: String
    var createdAt: Date
    var room: Room?
    @Relationship(deleteRule: .cascade, inverse: \ItemPhoto.item)
    var photos: [ItemPhoto] = []

    init() {
        self.name = ""
        self.brand = ""
        self.modelNumber = ""
        self.serial = ""
        self.quantity = 1
        self.unitValue = 0
        self.purchasePrice = nil
        self.purchaseDate = nil
        self.hasReceipt = false
        self.notes = ""
        self.createdAt = Date()
    }
}

enum PhotoKind: String, CaseIterable {
    case item, label, receipt

    var title: String {
        switch self {
        case .item: return "Photo"
        case .label: return "Label"
        case .receipt: return "Receipt"
        }
    }
}

@Model
final class ItemPhoto {
    /// Full photo, kept outside the database file.
    @Attribute(.externalStorage) var data: Data
    /// Small copy for lists and the PDF.
    var thumb: Data
    var kind: String
    var createdAt: Date
    var item: Item?

    init(data: Data, thumb: Data, kind: PhotoKind) {
        self.data = data
        self.thumb = thumb
        self.kind = kind.rawValue
        self.createdAt = Date()
    }
}

// MARK: - Derived values

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Home {
    var sortedRooms: [Room] { rooms.sorted { $0.order < $1.order } }
    var allItems: [Item] { rooms.flatMap { $0.items } }
    var totalValue: Double { allItems.reduce(0) { $0 + $1.totalValue } }
    var itemCount: Int { allItems.reduce(0) { $0 + $1.quantity } }
    var needsProofCount: Int { allItems.filter { !$0.hasProof }.count }
    var needsDetailsCount: Int { allItems.filter { $0.needsDetails }.count }
    /// Items that still need attention for any reason: no value, no name, or no proof.
    var needsReviewCount: Int { allItems.filter { $0.needsDetails || !$0.hasProof }.count }
}

extension Room {
    var totalValue: Double { items.reduce(0) { $0 + $1.totalValue } }
    var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }
    var sortedItems: [Item] { items.sorted { $0.createdAt > $1.createdAt } }
}

extension Item {
    var displayName: String { name.trimmed.isEmpty ? "Untitled item" : name.trimmed }
    var totalValue: Double { Double(quantity) * unitValue }
    var hasProof: Bool { !serial.trimmed.isEmpty || hasReceipt }
    var needsDetails: Bool { name.trimmed.isEmpty || unitValue <= 0 }
    var sortedPhotos: [ItemPhoto] { photos.sorted { $0.createdAt < $1.createdAt } }
    var detailLine: String {
        [brand.trimmed, modelNumber.trimmed].filter { !$0.isEmpty }.joined(separator: " ")
    }
    var coverThumb: Data? {
        let list = sortedPhotos
        return (list.first { $0.kind == PhotoKind.item.rawValue } ?? list.first)?.thumb
    }
}

// MARK: - Room presets

struct RoomPreset: Identifiable, Hashable {
    let name: String
    let symbol: String
    var id: String { name }

    static let all: [RoomPreset] = [
        RoomPreset(name: "Living room", symbol: "sofa.fill"),
        RoomPreset(name: "Kitchen", symbol: "refrigerator.fill"),
        RoomPreset(name: "Dining room", symbol: "fork.knife"),
        RoomPreset(name: "Primary bedroom", symbol: "bed.double.fill"),
        RoomPreset(name: "Bedroom", symbol: "bed.double"),
        RoomPreset(name: "Kids' room", symbol: "teddybear.fill"),
        RoomPreset(name: "Bathroom", symbol: "shower.fill"),
        RoomPreset(name: "Office", symbol: "desktopcomputer"),
        RoomPreset(name: "Laundry", symbol: "washer.fill"),
        RoomPreset(name: "Closets", symbol: "hanger"),
        RoomPreset(name: "Garage", symbol: "car.fill"),
        RoomPreset(name: "Attic & storage", symbol: "shippingbox.fill"),
        RoomPreset(name: "Basement", symbol: "stairs"),
        RoomPreset(name: "Outdoor & patio", symbol: "tree.fill"),
        RoomPreset(name: "Dock & boat", symbol: "sailboat.fill")
    ]

    /// Rooms most homes have, selected by default when creating a home.
    static let starter: [String] = ["Living room", "Kitchen", "Primary bedroom", "Bathroom", "Garage"]

    static let customSymbol = "square.grid.2x2.fill"
}

// MARK: - Image helpers

extension UIImage {
    /// Redraws the image upright and no larger than `maxSide` pixels on its long edge.
    func resized(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Returns (full photo, thumbnail) as JPEG data ready to store.
    func storagePair() -> (data: Data, thumb: Data)? {
        guard let full = resized(maxSide: 2000).jpegData(compressionQuality: 0.8),
              let small = resized(maxSide: 320).jpegData(compressionQuality: 0.75) else { return nil }
        return (full, small)
    }
}
