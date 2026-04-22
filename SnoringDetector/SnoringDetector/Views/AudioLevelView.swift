import SwiftUI

/// Slumber waveform — center-weighted bar visualization
/// matching the quiet aesthetic of the recording screen.
struct AudioLevelView: View {
    let level: Float
    private let barCount = 44

    var body: some View {
        GeometryReader { geo in
            let barW = max(2, (geo.size.width - CGFloat(barCount - 1) * 3) / CGFloat(barCount))
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule()
                        .fill(.white.opacity(isActive(i) ? 0.80 : 0.15))
                        .frame(width: barW,
                               height: barHeight(index: i, total: geo.size.height))
                        .animation(.easeOut(duration: 0.09), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func isActive(_ i: Int) -> Bool {
        Float(i) / Float(barCount) < level * 1.08
    }

    private func barHeight(index i: Int, total h: CGFloat) -> CGFloat {
        // Sinusoidal baseline gives natural, non-uniform look
        let base  = sin(Double(i) * 0.47 + 1.2) * 0.24 + 0.34
        let center = barCount / 2
        let spread = 1.0 - Double(abs(i - center)) / Double(center) * 0.42
        let boost  = Double(level) * Double(h) * 0.52 * spread
        return CGFloat(base) * h * 0.48 + CGFloat(boost)
    }
}
