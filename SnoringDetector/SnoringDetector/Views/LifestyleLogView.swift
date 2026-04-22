import SwiftUI

struct LifestyleLogView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss

    let date: Date
    @State private var log: LifestyleLog

    init(date: Date, existing: LifestyleLog?) {
        self.date = date
        _log = State(initialValue: existing ?? LifestyleLog(date: date))
    }

    private let fatigueTitles = ["非常に元気", "元気", "普通", "疲れ気味", "かなり疲労"]

    var body: some View {
        NavigationStack {
            Form {
                // Date header
                Section {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .symbolRenderingMode(.hierarchical).foregroundStyle(.indigo)
                        Text(AppDateFormatter.sessionDate.string(from: date))
                            .font(.headline)
                        Spacer()
                    }
                }

                // Lifestyle factors
                Section {
                    // Alcohol
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("飲酒量", systemImage: "wineglass")
                                .symbolRenderingMode(.hierarchical)
                            Spacer()
                            Text(alcoholLabel(log.alcoholUnits))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Slider(value: $log.alcoholUnits, in: 0...5, step: 0.5).tint(.purple)
                    }
                    .padding(.vertical, 2)

                    // Exercise
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("有酸素運動", systemImage: "figure.run")
                                .symbolRenderingMode(.hierarchical)
                            Spacer()
                            Text("\(log.exerciseMinutes)分")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(log.exerciseMinutes) },
                            set: { log.exerciseMinutes = Int($0) }
                        ), in: 0...180, step: 10).tint(.green)
                    }
                    .padding(.vertical, 2)

                    // Fatigue
                    VStack(alignment: .leading, spacing: 8) {
                        Label("疲労度", systemImage: "battery.25")
                            .symbolRenderingMode(.hierarchical)
                        HStack(spacing: 10) {
                            ForEach(1...5, id: \.self) { level in
                                Button {
                                    log.fatigueLevel = level
                                } label: {
                                    Image(systemName: level <= log.fatigueLevel ? "star.fill" : "star")
                                        .foregroundStyle(level <= log.fatigueLevel ? .orange : .secondary)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                            Text(fatigueTitles[log.fatigueLevel - 1])
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    // Weight
                    HStack {
                        Label("体重", systemImage: "scalemass")
                            .symbolRenderingMode(.hierarchical)
                        Spacer()
                        TextField("-- ", value: $log.weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("kg").foregroundStyle(.secondary)
                    }
                } header: { Text("ライフスタイル") } footer: {
                    Text("飲酒・運動・疲労はいびきの発生に影響します。毎日記録することで傾向が見えてきます。")
                }

                // Countermeasures
                Section {
                    ForEach(Countermeasure.allCases) { m in
                        Toggle(isOn: Binding(
                            get: { log.countermeasures.contains(m) },
                            set: { on in
                                if on { if !log.countermeasures.contains(m) { log.countermeasures.append(m) } }
                                else  { log.countermeasures.removeAll { $0 == m } }
                            }
                        )) {
                            Label(m.rawValue, systemImage: m.icon)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                } header: { Text("実施した対策") } footer: {
                    Text("使用した対策グッズや工夫を記録して、効果を比較できます。")
                }

                // Oral exercises
                Section {
                    ForEach(OralExercise.allCases) { ex in
                        let done = log.exercises.contains(where: { $0.exercise == ex })
                        Button {
                            if done { log.exercises.removeAll { $0.exercise == ex } }
                            else     { log.exercises.append(ExerciseEntry(exercise: ex)) }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(done ? .green : .secondary)
                                    .font(.title3)
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.rawValue)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text(ex.instruction)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: { Text("口腔・顔面筋エクササイズ") } footer: {
                    Text("継続することでいびきの改善が期待できます。気軽に行えるものから始めましょう。")
                }

                // Notes
                Section("メモ") {
                    TextField("その他の気づきを記入", text: $log.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("ライフスタイル記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        dataStore.saveLog(log)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func alcoholLabel(_ v: Double) -> String {
        switch v {
        case 0:         return "なし"
        case 0..<1:     return "少量（\(v)杯）"
        case 1..<3:     return "\(Int(v))杯（適量）"
        case 3..<5:     return "\(Int(v))杯（多め）"
        default:        return "5杯以上（かなり多め）"
        }
    }
}
