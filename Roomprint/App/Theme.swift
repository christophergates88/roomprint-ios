import SwiftUI
import UIKit

extension Color {
    /// Brand navy, used for the summary card and logo.
    static let rpNavy = Color(red: 22 / 255, green: 38 / 255, blue: 58 / 255)
    /// Warm off-white used on navy.
    static let rpVellum = Color(red: 243 / 255, green: 238 / 255, blue: 226 / 255)
    /// The "record" red from the logo dot.
    static let rpRecord = Color(red: 229 / 255, green: 83 / 255, blue: 61 / 255)
    /// Deeper red for buttons with white text (better contrast).
    static let rpRecordDeep = Color(red: 199 / 255, green: 67 / 255, blue: 46 / 255)
    static let rpGround = Color(UIColor.systemGroupedBackground)
    static let rpCard = Color(UIColor.secondarySystemGroupedBackground)
}

enum Money {
    static var code: String { Locale.current.currency?.identifier ?? "USD" }

    static func string(_ value: Double) -> String {
        value.formatted(.currency(code: code).precision(.fractionLength(0)))
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.rpCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

/// The Roomprint mark: house outline, viewfinder corners, red record dot.
struct LogoMark: View {
    var size: CGFloat = 64

    var body: some View {
        Canvas { context, canvasSize in
            let k = canvasSize.width / 64
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }

            let background = Path(roundedRect: CGRect(origin: .zero, size: canvasSize),
                                  cornerRadius: 14 * k, style: .continuous)
            context.fill(background, with: .color(.rpNavy))

            var house = Path()
            house.move(to: p(12, 29))
            house.addLine(to: p(32, 13))
            house.addLine(to: p(52, 29))
            house.addLine(to: p(52, 51))
            house.addLine(to: p(12, 51))
            house.closeSubpath()
            context.stroke(house, with: .color(.rpVellum),
                           style: StrokeStyle(lineWidth: 4.5 * k, lineJoin: .round))

            let segments: [[(CGFloat, CGFloat)]] = [
                [(21, 34), (21, 31), (24, 31)],
                [(43, 34), (43, 31), (40, 31)],
                [(21, 41), (21, 44), (24, 44)],
                [(43, 41), (43, 44), (40, 44)]
            ]
            var corners = Path()
            for segment in segments {
                guard let first = segment.first else { continue }
                corners.move(to: p(first.0, first.1))
                for point in segment.dropFirst() {
                    corners.addLine(to: p(point.0, point.1))
                }
            }
            context.stroke(corners, with: .color(.rpVellum),
                           style: StrokeStyle(lineWidth: 2.6 * k, lineCap: .round, lineJoin: .round))

            let dot = CGRect(x: (32 - 3.6) * k, y: (37.5 - 3.6) * k, width: 7.2 * k, height: 7.2 * k)
            context.fill(Path(ellipseIn: dot), with: .color(.rpRecord))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Square photo thumbnail with a soft placeholder.
struct Thumb: View {
    let data: Data?
    var size: CGFloat = 56
    var symbol: String = "photo"

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(UIColor.tertiarySystemFill)
                    Image(systemName: symbol)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Small pill label, e.g. "PRO" or "3 need proof".
struct Pill: View {
    let text: String
    var color: Color = .rpRecordDeep

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(color, in: Capsule())
    }
}

@MainActor
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
