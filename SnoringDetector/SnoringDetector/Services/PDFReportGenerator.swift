import UIKit
import Foundation

// Generates a medical-style PDF report from sleep session data.
enum PDFReportGenerator {

    static func generate(sessions: [SleepSession], days: Int) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            draw(ctx: ctx, sessions: sessions, days: days, pageRect: pageRect)
        }
    }

    // MARK: - Private drawing

    private static func draw(
        ctx: UIGraphicsPDFRendererContext,
        sessions: [SleepSession],
        days: Int,
        pageRect: CGRect
    ) {
        let W = pageRect.width
        var y: CGFloat = 44

        // ── Header ──────────────────────────────────────────────
        let accentColor = UIColor(red: 0.27, green: 0.27, blue: 0.82, alpha: 1)
        "いびき・睡眠レポート".draw(
            at: CGPoint(x: 44, y: y),
            withAttributes: [.font: UIFont.systemFont(ofSize: 20, weight: .bold), .foregroundColor: accentColor]
        )
        y += 28

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP"); fmt.dateFormat = "yyyy年M月d日"
        let endDate   = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        let sub = "\(fmt.string(from: startDate)) 〜 \(fmt.string(from: endDate))（過去\(days)日間）　作成日: \(fmt.string(from: endDate))"
        sub.draw(
            at: CGPoint(x: 44, y: y),
            withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.gray]
        )
        y += 22

        line(from: CGPoint(x: 44, y: y), to: CGPoint(x: W - 44, y: y), color: UIColor.systemGray4)
        y += 16

        // ── Summary ──────────────────────────────────────────────
        section("■ サマリー", at: CGPoint(x: 44, y: y)); y += 22

        guard !sessions.isEmpty else {
            "この期間のデータがありません".draw(
                at: CGPoint(x: 60, y: y),
                withAttributes: body()
            )
            return
        }

        let n         = Double(sessions.count)
        let avgScore  = sessions.map { Double($0.qualityScore) }.reduce(0, +) / n
        let avgSnore  = sessions.map(\.snoringPercentage).reduce(0, +) / n
        let avgDur    = sessions.map(\.duration).reduce(0, +) / n
        let totApnea  = sessions.reduce(0) { $0 + $1.apneaEvents.count }
        let maxSAS    = sessions.map(\.sasRiskScore).max() ?? 0

        let rows: [(String, String)] = [
            ("計測回数",           "\(sessions.count) 回"),
            ("平均睡眠時間",         TimeFormat.longDuration(avgDur)),
            ("平均睡眠スコア",        String(format: "%.0f 点", avgScore)),
            ("平均いびき割合",        String(format: "%.1f%%", avgSnore)),
            ("無呼吸候補イベント合計",   "\(totApnea) 件"),
            ("最大SASリスクスコア",   String(format: "%.0f / 100", maxSAS)),
        ]
        for (label, value) in rows {
            label.draw(at: CGPoint(x: 60, y: y), withAttributes: body())
            value.draw(
                at: CGPoint(x: 240, y: y),
                withAttributes: [.font: UIFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: UIColor.black]
            )
            y += 18
        }
        y += 12

        // ── Nightly table ────────────────────────────────────────
        section("■ 記録一覧", at: CGPoint(x: 44, y: y)); y += 22

        let cols: [(String, CGFloat)] = [
            ("日付", 44), ("睡眠", 138), ("いびき", 200), ("スコア", 265),
            ("無呼吸", 330), ("SAS", 396), ("主な姿勢", 448)
        ]

        // Header bar
        let hRect = CGRect(x: 44, y: y - 2, width: W - 88, height: 18)
        accentColor.setFill(); UIBezierPath(roundedRect: hRect, cornerRadius: 3).fill()
        let hAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .semibold), .foregroundColor: UIColor.white]
        for (title, x) in cols { title.draw(at: CGPoint(x: x + 2, y: y), withAttributes: hAttr) }
        y += 20

        let rowFmt = DateFormatter(); rowFmt.locale = Locale(identifier: "ja_JP"); rowFmt.dateFormat = "M/d(E)"
        for (idx, s) in sessions.enumerated() {
            if y > 780 { ctx.beginPage(); y = 44 }
            if idx % 2 == 0 {
                UIColor(white: 0.96, alpha: 1).setFill()
                UIBezierPath(rect: CGRect(x: 44, y: y - 2, width: W - 88, height: 16)).fill()
            }
            let values: [String] = [
                rowFmt.string(from: s.startDate),
                TimeFormat.longDuration(s.duration),
                String(format: "%.0f%%", s.snoringPercentage),
                "\(s.qualityScore)点",
                "\(s.apneaEvents.count)件",
                String(format: "%.0f", s.sasRiskScore),
                s.dominantPosition.rawValue
            ]
            let sAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.black]
            for (i, v) in values.enumerated() { v.draw(at: CGPoint(x: cols[i].1 + 2, y: y), withAttributes: sAttr) }
            y += 15
        }
        y += 20

        // ── Disclaimer ───────────────────────────────────────────
        if y > 750 { ctx.beginPage(); y = 44 }
        let disc: [NSAttributedString.Key: Any] = [.font: UIFont.italicSystemFont(ofSize: 9), .foregroundColor: UIColor.gray]
        "【注意】このレポートは参考情報であり、医療診断を目的としたものではありません。".draw(at: CGPoint(x: 44, y: y), withAttributes: disc); y += 14
        "SASリスクスコアが高い場合は、耳鼻咽喉科・睡眠外来への受診をお勧めします。".draw(at: CGPoint(x: 44, y: y), withAttributes: disc); y += 14
        "本データはいびき計測アプリで記録されたものです。".draw(at: CGPoint(x: 44, y: y), withAttributes: disc)
    }

    // MARK: - Drawing helpers

    private static func section(_ title: String, at point: CGPoint) {
        title.draw(at: point, withAttributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.black
        ])
    }

    private static func body() -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.black]
    }

    private static func line(from: CGPoint, to: CGPoint, color: UIColor) {
        let p = UIBezierPath(); p.move(to: from); p.addLine(to: to)
        color.setStroke(); p.lineWidth = 0.5; p.stroke()
    }
}
