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

## セットアップ手順

### 1. 事前準備

| 必要なもの | バージョン | 入手先 |
|-----------|-----------|--------|
| Xcode | 15.0 以上 | Mac App Store |
| Apple Developer アカウント | 無料アカウントで可 | developer.apple.com |
| iPhone | iOS 17 以上 | — |
| Apple Watch（任意） | watchOS 10 以上 | — |

> **注意：** マイクを使用するため実機が必要です。シミュレータでは音声入力が動作しません。

---

### 2. プロジェクトを開く

```bash
# リポジトリをクローン（またはダウンロード）
git clone <リポジトリURL>
cd SnoringDetector

# Xcode でプロジェクトを開く
open SnoringDetector.xcodeproj
```

---

### 3. Signing（署名）の設定

**iPhone ターゲット：**

1. Xcode 左ペインのプロジェクトナビゲータで **SnoringDetector** プロジェクトをクリック
2. ターゲット一覧から **SnoringDetector** を選択
3. **Signing & Capabilities** タブを開く
4. **Team** のプルダウンから自分の Apple ID を選択
   - Apple ID 未登録の場合：**Add Account...** → Apple ID でサインイン
5. **Bundle Identifier** を一意の値に変更（例：`com.yourname.SnoringDetector`）
6. **Automatically manage signing** にチェックが入っていることを確認

**Apple Watch ターゲット（Watch を使う場合）：**

1. ターゲット一覧から **SnoringDetectorWatch** を選択
2. 同様に Team を設定
3. Bundle Identifier を `com.yourname.SnoringDetector.watchkitapp` に変更

---

### 4. Capabilities（機能）の追加

**SnoringDetector ターゲット** の **Signing & Capabilities** で以下を確認・追加します：

#### HealthKit（任意）
1. **+ Capability** をクリック
2. **HealthKit** を検索して追加
3. チェックボックスは **Clinical Health Records** 以外をオン

#### Background Modes（バックグラウンド録音）
1. **+ Capability** をクリック
2. **Background Modes** を追加
3. **Audio, AirPlay, and Picture in Picture** にチェック
   > これにより画面オフ中も録音が継続されます

#### WatchConnectivity（Watch 連携）
- 追加のCapabilityは不要ですが、**SnoringDetectorWatch** ターゲットにも同じ Team が設定されていることを確認してください

---

### 5. iPhone を実機接続して実行

1. iPhone を USB ケーブルで Mac に接続
2. iPhone で「**このコンピュータを信頼しますか？**」が表示されたら **信頼** をタップ
3. Xcode 上部のデバイス選択で自分の iPhone を選択
4. **▶ 実行** ボタンを押す（または `Cmd + R`）
5. 初回ビルド時に **「デベロッパAppを信頼する」** の設定が必要：
   - iPhone の **設定 → 一般 → VPNとデバイス管理** を開く
   - 自分の Apple ID を選択 → **信頼** をタップ

---

### 6. Apple Watch アプリのインストール（任意）

1. iPhone と Apple Watch がペアリング済みであることを確認
2. Xcode のスキーム選択で **SnoringDetector** → デバイス選択で iPhone を選択
   （Watch アプリは iPhone アプリのインストール時に自動的に Watch へ転送されます）
3. ビルド・実行後、Watch の **App Store** または iPhone の **Watch アプリ** から
   インストールを確認
4. Watch アプリが自動でインストールされない場合：
   - iPhone の **Watch アプリ** → **自分の文字盤** → **インストール可能なApp** を確認

---

### 7. 初回起動時の権限設定

#### マイクアクセス（必須）
- アプリ起動後、計測ボタンを押すと許可ダイアログが表示されます
- **OK** をタップ
- 後から変更する場合：**設定 → プライバシーとセキュリティ → マイク → いびき検出**

#### HealthKit（任意）
- アプリの **設定タブ → HealthKit連携 → 連携する** をタップ
- 睡眠分析の読み取り・書き込みを許可

---

### 8. 使い方

1. **ダッシュボード** で「計測開始」をタップ
2. iPhoneを**ベッドのそば**（枕元 50cm 以内）に置く
3. 画面が消えても録音は継続（バックグラウンド録音有効時）
4. 朝起きたら「**停止**」をタップ
5. **履歴タブ**でスコアとタイムラインを確認

> **ヒント：** iPhoneの充電器に接続した状態で計測すると、バッテリー残量を気にせず一晩計測できます。

---

### 9. トラブルシューティング

| 症状 | 対処法 |
|------|--------|
| ビルドエラー「No team selected」 | Signing & Capabilities で Team を設定 |
| ビルドエラー「Bundle ID already in use」 | Bundle Identifier を変更（yourname を自分の名前に） |
| Watch アプリが表示されない | iPhone と Watch が同じ Apple ID でペアリングされているか確認 |
| いびきが検出されない | 設定画面で検出感度を「高」に調整 / iPhone をより近くに置く |
| バックグラウンドで録音が止まる | Background Modes Capability の **Audio** にチェックが入っているか確認 |
| HealthKit に保存されない | 設定 → プライバシーとセキュリティ → ヘルスケア で権限を確認 |

## プライバシー

録音データはデバイス内にのみ保存され、外部サーバーには送信されません。
HealthKit データは Apple のセキュリティポリシーに従い管理されます。
