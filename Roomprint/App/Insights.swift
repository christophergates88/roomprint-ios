import Foundation

/// Kinds of belongings that homeowners and renters policies commonly pay only up to a small fixed
/// amount for, unless they are listed separately. Roomprint only points them out; the policy decides.
struct SpecialLimit: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let keywords: [String]

    static let all: [SpecialLimit] = [
        SpecialLimit(id: "jewelry", title: "Jewelry and watches", symbol: "sparkles",
                     keywords: ["jewel", "ring", "necklace", "bracelet", "earring", "watch", "diamond", "rolex", "pearl"]),
        SpecialLimit(id: "firearms", title: "Firearms", symbol: "scope",
                     keywords: ["firearm", "rifle", "shotgun", "pistol", "handgun", "revolver", "gun"]),
        SpecialLimit(id: "collect", title: "Cash, coins and collectibles", symbol: "banknote",
                     keywords: ["cash", "coin", "collectible", "collection", "stamp", "trading card", "memorabilia", "comic"]),
        SpecialLimit(id: "silver", title: "Silverware and china", symbol: "fork.knife",
                     keywords: ["silverware", "sterling", "flatware", "fine china"]),
        SpecialLimit(id: "art", title: "Art and antiques", symbol: "photo.artframe",
                     keywords: ["painting", "sculpture", "antique", "fine art", "artwork"]),
        SpecialLimit(id: "boats", title: "Boats and trailers", symbol: "sailboat",
                     keywords: ["boat", "kayak", "canoe", "jet ski", "trailer", "outboard", "paddle board"])
    ]

    /// Whole-word-start match, so "ring" doesn't catch "refrigerator" or "spring".
    func matches(_ name: String) -> Bool {
        let words = name.lowercased().split { !$0.isLetter }.map(String.init)
        let joined = " " + words.joined(separator: " ") + " "
        return keywords.contains { key in
            key.contains(" ") ? joined.contains(" " + key) : words.contains { $0 == key || $0 == key + "s" || ($0.hasPrefix(key) && key.count >= 5) }
        }
    }
}

struct SpecialLimitTotal: Identifiable {
    let limit: SpecialLimit
    let value: Double
    let count: Int
    var id: String { limit.id }
}

extension Home {
    /// Recorded value in each commonly capped category, biggest first.
    var specialLimitTotals: [SpecialLimitTotal] {
        let items = allItems
        return SpecialLimit.all.compactMap { limit in
            let hits = items.filter { limit.matches($0.name) }
            let value = hits.reduce(0) { $0 + $1.totalValue }
            return value > 0 ? SpecialLimitTotal(limit: limit, value: value, count: hits.count) : nil
        }
        .sorted { $0.value > $1.value }
    }

    /// Recorded value above the coverage the owner typed in (0 when covered or not entered).
    var coverageGap: Double { coverageLimit > 0 ? max(0, totalValue - coverageLimit) : 0 }
}

/// Things people leave off an inventory, by kind of room, with a typical replacement cost to start from.
struct MissedItem: Identifiable, Hashable {
    let name: String
    let value: Double
    var id: String { name }

    private static func m(_ name: String, _ value: Double) -> MissedItem { MissedItem(name: name, value: value) }

    private static let table: [(keys: [String], items: [MissedItem])] = [
        (["kitchen"], [m("Small appliances", 350), m("Pots and pans", 400), m("Knives and utensils", 250),
                       m("Dishes and glassware", 400), m("Food in pantry and freezer", 600), m("Kitchen linens", 100)]),
        (["living", "family", "great", "den"], [m("Curtains and blinds", 400), m("Lamps", 250), m("Wall art and frames", 300),
                       m("Throw pillows and blankets", 150), m("Board games and books", 300), m("Cables and remotes", 100)]),
        (["dining"], [m("Serving dishes", 300), m("Table linens", 150), m("Glassware and barware", 300), m("Curtains", 250)]),
        (["kids", "nursery"], [m("Toys", 600), m("Children's clothing", 800), m("Children's books", 200),
                       m("Stroller and car seat", 500), m("Bedding", 200)]),
        (["bed", "guest"], [m("Clothing", 2500), m("Shoes", 600), m("Bedding and pillows", 400), m("Curtains", 200),
                       m("Luggage", 300), m("Lamps", 150)]),
        (["bath"], [m("Towels and linens", 250), m("Toiletries and cosmetics", 400), m("Hair dryer and styling tools", 200),
                       m("Medicines and first aid", 150)]),
        (["office", "study"], [m("Chargers and cables", 150), m("Router and networking", 200), m("Books", 300),
                       m("Office supplies", 150), m("Headphones", 200)]),
        (["laundry", "mud", "utility"], [m("Washer", 900), m("Dryer", 800), m("Vacuum", 300), m("Iron and ironing board", 80),
                       m("Cleaning supplies", 150)]),
        (["closet"], [m("Coats and jackets", 600), m("Shoes", 600), m("Handbags", 500), m("Luggage", 300),
                       m("Spare linens", 300)]),
        (["garage", "shop", "shed"], [m("Hand tools", 600), m("Lawn and garden tools", 400), m("Ladders", 250),
                       m("Sports gear", 500), m("Camping gear and coolers", 400), m("Holiday decorations", 400)]),
        (["attic", "storage", "basement"], [m("Holiday decorations", 500), m("Luggage", 300), m("Seasonal clothing", 500),
                       m("Camping gear", 500), m("Keepsakes and photo albums", 300)]),
        (["outdoor", "patio", "porch", "deck", "yard"], [m("Grill", 500), m("Patio furniture", 1200), m("Hoses and garden tools", 200),
                       m("Planters", 200), m("Outdoor toys and play sets", 400)]),
        (["dock", "boat"], [m("Life jackets", 300), m("Fishing gear", 600), m("Tubes and water toys", 300),
                       m("Dock box and ropes", 250), m("Coolers", 200)])
    ]

    private static let fallback = [m("Curtains and blinds", 300), m("Lamps", 200), m("Rugs", 300), m("Wall art and frames", 250)]

    /// Suggestions for a room, leaving out anything the room already seems to have.
    static func suggestions(for room: Room) -> [MissedItem] {
        let name = room.name.lowercased()
        let list = table.first { entry in entry.keys.contains { name.contains($0) } }?.items ?? fallback
        let have = room.items.map { $0.name.lowercased().trimmed }.filter { $0.count >= 3 }
        return list.filter { candidate in
            let key = candidate.name.lowercased().split(separator: " ").first.map(String.init) ?? ""
            return !have.contains { $0.contains(key) || candidate.name.lowercased().contains($0) }
        }
    }
}
