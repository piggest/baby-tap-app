# baby-tap-app

赤ちゃんがトラックパッド・キーボード・マウスを叩くと、絵文字・パーティクル・効果音で反応する macOS ネイティブ kiosk アプリ。

v2.0 から Electron 版から **Swift + SpriteKit ネイティブ実装** に置き換え。

## 特徴

- フルスクリーン kiosk モード
- **MultitouchSupport.framework で生トラックパッドデータを取得** (3本指以上でも全指反応)
- マウスは移動・ボタンクリック・ドラッグすべてで反応
- 任意のキー入力で反応 (Cmd/Ctrl/Opt 修飾なし)
- 絵文字、文字 (ひらがな/英字/数字)、図形パーティクル、波紋＋キラキラ、横切るキャラクター
- AVAudioEngine によるプロシージャル効果音
- **CGEventTap でメディアキー (音量/輝度/再生制御) をブロック**

## 必要環境

- macOS 12.0+ (Apple Silicon)
- Xcode Command Line Tools

## ビルド・起動

```bash
./scripts/build-app.sh
open release/BabyTap.app
```

`scripts/build-app.sh` が swift build → .app バンドル生成 → ad-hoc 署名まで実行する。

開発中の直接起動：

```bash
swift run -c release
```

ただし `.app` 化していないと kiosk 動作 (フルスクリーン等) が不完全。

## 終了方法

| キー | 動作 |
|---|---|
| `Cmd + Q` | 通常終了 |
| `Cmd + Shift + Q` | 強制終了 (バイパスキー) |

## アクセシビリティ権限

メディアキー (音量/輝度/再生制御) をブロックするには **アクセシビリティ権限** が必要。
初回起動時に macOS のプロンプトが出たら許可してください。

```
システム設定 → プライバシーとセキュリティ → アクセシビリティ
```

ここで BabyTap にチェックを入れてからアプリを再起動。

## ブロックされるキー

- 音量 Up / Down / Mute
- 輝度 Up / Down
- 再生 / 早送り / 巻き戻し / 次へ / 前へ
- Eject
- キーボードバックライト Up / Down / Toggle

## アーキテクチャ

| ファイル | 役割 |
|---|---|
| `Sources/BabyTap/main.swift` | アプリ起動エントリ |
| `Sources/BabyTap/AppDelegate.swift` | ウィンドウ/メニュー/各サブシステム統括 |
| `Sources/BabyTap/BabyTapView.swift` | マウス・キー・タッチ入力受付 NSView |
| `Sources/BabyTap/BabyTapScene.swift` | SpriteKit シーン、演出 |
| `Sources/BabyTap/SoundEngine.swift` | AVAudioEngine プロシージャル効果音 |
| `Sources/BabyTap/MediaKeyBlocker.swift` | CGEventTap でメディアキー破棄 |
| `Sources/BabyTap/TrackpadMonitor.swift` | MultitouchSupport.framework 経由で生指データ取得 |
| `Resources/Info.plist` | アプリのメタデータ |
| `scripts/build-app.sh` | .app バンドル生成 |

## バイナリからの起動 (リリース DMG)

リリース DMG (`BabyTap-x.y.z-arm64.dmg`) はコード署名されていません。初回起動時に Gatekeeper の警告が出ます。

1. `.app` を Finder で右クリック → 「開く」
2. 警告ダイアログで「開く」を選択

以降は通常通り起動できます。

## ライセンス

MIT
