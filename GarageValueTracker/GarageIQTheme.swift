import SwiftUI

// MARK: - Color Palette

enum GIQ {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let cardSurface = Color(red: 0.10, green: 0.10, blue: 0.10)
    static let cardBorder = Color(red: 0.83, green: 0.66, blue: 0.26).opacity(0.25)
    static let accent = Color(red: 0.83, green: 0.66, blue: 0.26)
    static let accentMuted = Color(red: 0.83, green: 0.66, blue: 0.26).opacity(0.6)
    static let gain = Color(red: 0.2, green: 0.85, blue: 0.4)
    static let loss = Color(red: 0.95, green: 0.3, blue: 0.3)
    static let secondaryText = Color.white.opacity(0.45)
    static let tertiaryText = Color.white.opacity(0.30)
    static let divider = Color.white.opacity(0.08)

    static let holdBadge = Color.white.opacity(0.25)
    static let sellWindowBadge = Color(red: 0.83, green: 0.66, blue: 0.26)
    static let sellBadge = Color(red: 0.2, green: 0.85, blue: 0.4)

    static let liquidityBar = Color.green
    static let volatilityBar = Color.yellow
    static let cyclicalityBar = Color.blue

    static let segmentColors: [Color] = [
        .orange, .blue, .purple, .green, .red, .teal, .pink
    ]
}

// MARK: - Fonts

extension Font {
    static func mono(_ style: Font.TextStyle) -> Font {
        .system(style, design: .monospaced)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Card Modifier

struct ThemeCard: ViewModifier {
    var borderColor: Color = GIQ.cardBorder

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(GIQ.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}

extension View {
    func themeCard(border: Color = GIQ.cardBorder) -> some View {
        modifier(ThemeCard(borderColor: border))
    }

    func themeBackground() -> some View {
        self.background(GIQ.background.ignoresSafeArea())
    }
}

// MARK: - Signal Badge

struct SignalBadge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = GIQ.holdBadge) {
        self.text = text
        self.color = color
    }

    static func hold() -> SignalBadge { SignalBadge("HOLD", color: GIQ.holdBadge) }
    static func sellWindow() -> SignalBadge { SignalBadge("SELL WINDOW", color: GIQ.sellWindowBadge) }
    static func sell() -> SignalBadge { SignalBadge("SELL", color: GIQ.sellBadge) }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .tracking(0.5)
            .foregroundColor(color == GIQ.holdBadge ? .white.opacity(0.7) : .black)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Section Header

struct GIQSectionHeader: View {
    let label: String
    let headline: String
    var accentWord: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(GIQ.secondaryText)
                .tracking(1.5)

            if let accentWord = accentWord,
               let range = headline.range(of: accentWord, options: .caseInsensitive) {
                let before = String(headline[headline.startIndex..<range.lowerBound])
                let accent = String(headline[range])
                let after = String(headline[range.upperBound...])
                (Text(before).foregroundColor(.white) +
                 Text(accent).foregroundColor(GIQ.accent) +
                 Text(after).foregroundColor(.white))
                    .font(.system(size: 28, weight: .bold))
            } else {
                Text(headline)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - PRO Badge

struct PROBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(GIQ.gain)
                .frame(width: 6, height: 6)
            Text("PRO")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - App Header Bar

struct GIQHeaderBar: View {
    var trailing: (() -> AnyView)? = nil

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(GIQ.accent)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("G")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                    )
                Text("GARAGE IQ")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Spacer()
            PROBadge()
            if let trailing = trailing {
                trailing()
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Sparkline

struct Sparkline: View {
    let values: [Double]
    var color: Color = GIQ.gain
    var height: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            if values.count >= 2 {
                let minV = values.min() ?? 0
                let maxV = values.max() ?? 1
                let range = max(maxV - minV, 1)

                Path { path in
                    for (i, val) in values.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                        let y = geo.size.height * (1 - CGFloat((val - minV) / range))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                let lastVal = values.last ?? 0
                let lastX = geo.size.width
                let lastY = geo.size.height * (1 - CGFloat((lastVal - minV) / range))
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .position(x: lastX, y: lastY)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Horizontal Progress Bar

struct HProgressBar: View {
    let value: Double
    let maxValue: Double
    var color: Color = .blue

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.08))

                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(geo.size.width * CGFloat(min(value / maxValue, 1.0)), 4))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Currency Formatter

func giqCurrency(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
}
