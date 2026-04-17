import SwiftUI

/// Voice-Memos-style real-time audio waveform.
struct AudioLevelView: View {
    let level: Float
    private let barCount = 44

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(.white.opacity(isActive(i) ? 0.85 : 0.18))
                        .frame(width: max(2, (geo.size.width - CGFloat(barCount - 1) * 3) / CGFloat(barCount)))
                        .frame(height: barHeight(index: i, totalHeight: geo.size.height))
                        .animation(.easeOut(duration: 0.08), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func isActive(_ i: Int) -> Bool {
        Float(i) / Float(barCount) < level * 1.1
    }

    private func barHeight(index: Int, totalHeight: CGFloat) -> CGFloat {
        // Natural-looking pseudo-random baseline using sin
        let base = sin(Double(index) * 0.47 + 1.2) * 0.25 + 0.35
        let center = barCount / 2
        let distance = abs(index - center)
        let spread = 1.0 - Double(distance) / Double(center) * 0.45
        let boost = Double(level) * Double(totalHeight) * 0.55 * spread
        return CGFloat(base) * totalHeight * 0.5 + CGFloat(boost)
    }
}
