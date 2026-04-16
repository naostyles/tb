# いびき検出アプリ (Snoring Detector)

iPhone と Apple Watch でいびきをリアルタイム計測・分析するアプリです。

## 機能

### iPhone アプリ
- **リアルタイムいびき検出** — AVAudioEngine + FFT によるいびき周波数分析（80〜500 Hz）
- **ダッシュボード** — 今週の平均スコア、計測開始ボタン、前回の記録サマリー
- **計測画面** — 音声波形ビジュアライザー、いびき検出アニメーション、リアルタイム統計
- **履歴画面** — 睡眠スコアの推移グラフ（Swift Charts）、セッション一覧
- **詳細画面** — タイムライン、いびきイベント一覧、スコア円グラフ
- **設定画面** — 検出感度・周波数帯の調整、HealthKit 連携

### Apple Watch アプリ
- **計測コントロール** — Watch から iPhone のいびき計測を開始/停止
- **リアルタイム状態表示** — いびき検出時に画面色・アイコンが変化
- **ハプティクス通知** — いびきを検出したときに触覚フィードバック
- **サマリー表示** — 前回セッションの睡眠スコア・いびき割合

## アーキテクチャ

```
SnoringDetector/
├── SnoringDetector/          # iOS アプリ
│   ├── Models/
│   │   ├── SleepSession.swift        # 睡眠セッションモデル
│   │   └── SnoringEvent.swift        # いびきイベントモデル
│   ├── Services/
│   │   ├── AudioRecorder.swift       # AVAudioEngine による録音
│   │   ├── SnoringDetectionEngine.swift  # FFT いびき検出エンジン
│   │   ├── DataStore.swift           # UserDefaults 永続化
│   │   ├── HealthKitManager.swift    # HealthKit 連携
│   │   └── WatchConnectivityManager.swift  # Watch 通信
│   └── Views/
│       ├── DashboardView.swift       # ホーム画面
│       ├── SessionView.swift         # 計測中画面
│       ├── HistoryView.swift         # 履歴一覧
│       ├── SessionDetailView.swift   # セッション詳細
│       ├── SnoringChartView.swift    # Charts グラフ
│       ├── AudioLevelView.swift      # 音声レベルバー
│       └── SettingsView.swift        # 設定
└── SnoringDetectorWatch/     # watchOS アプリ
    ├── WatchApp.swift
    ├── WatchContentView.swift
    ├── WatchSessionView.swift        # 計測コントロール & サマリー
    ├── WatchConnectivityService.swift
    └── WatchDataModel.swift
```

## いびき検出の仕組み

1. **音声取得** — AVAudioEngine でマイク入力をリアルタイムバッファリング
2. **振幅フィルタ** — RMS が設定閾値未満の場合は無音として除外
3. **FFT 周波数解析** — Accelerate フレームワークの `vDSP_fft_zrip` で高速フーリエ変換
4. **いびき判定** — 80〜500 Hz 帯域のエネルギーが全体の 45% 以上なら「いびき候補」
5. **確認ウィンドウ** — 0.8 秒以上継続して検出された場合にいびきと確定
6. **イベント記録** — 開始時刻・終了時刻・強度・セッション経過時間を保存

## 必要要件

- **iOS** 17.0 以上
- **watchOS** 10.0 以上
- **Xcode** 15.0 以上
- マイクアクセス許可（必須）
- HealthKit アクセス許可（任意）

## セットアップ

1. `SnoringDetector.xcodeproj` を Xcode で開く
2. Signing & Capabilities でチームを設定
3. iPhone と Apple Watch の実機またはシミュレータで実行
4. マイクアクセスを許可して計測開始

## プライバシー

録音データはデバイス内にのみ保存され、外部サーバーには送信されません。
HealthKit データは Apple のセキュリティポリシーに従い管理されます。
