import SwiftUI

struct AudioLevelView: View {
    let level: Float
    private let barCount = 40

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    let threshold = Float(index) / Float(barCount)
                    let active = threshold < level
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(index: index, active: active))
                        .frame(width: (geo.size.width - CGFloat(barCount - 1) * 3) / CGFloat(barCount))
                        .frame(height: barHeight(index: index, geo: geo))
                        .animation(.easeOut(duration: 0.1), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func barHeight(index: Int, geo: GeometryProxy) -> CGFloat {
        let center = barCount / 2
        let distance = abs(index - center)
        let normalizedDist = CGFloat(distance) / CGFloat(center)
        let baseHeight = geo.size.height * (0.3 + (1 - normalizedDist) * 0.7)
        let levelBoost = CGFloat(level) * geo.size.height * 0.4
        return baseHeight + levelBoost * (1 - normalizedDist)
    }

    private func barColor(index: Int, active: Bool) -> Color {
        guard active else { return Color.white.opacity(0.15) }
        let t = Double(index) / Double(barCount)
        return Color(hue: 0.6 - t * 0.3, saturation: 0.8, brightness: 0.9)
    }
}
