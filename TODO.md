# Krita iPadOS Port TODO

この文書は、KritaをiPadOS実機で起動し、Android版に近い主要描画機能を使える状態にするための実装計画である。

## 目標

- iPadOS 17以降のarm64実機で起動する。
- Apple Pencilとタッチで実用的に描画できる。
- KRA/ORA/PNG/JPEGの読み書きを行える。
- Android版にある主要なブラシ、ツール、Docker、フィルタを利用できる。
- 同一revisionから再現可能にビルドできる。

## 前提と非目標

- 最終ターゲットはiPad実機。Simulatorは初期診断用途に限る。
- Qt 6系を使用する。
- NixはOSS依存物とホストツールの固定に使い、Xcode/iOS SDK、開発署名、実機インストールはXcodeに任せる。
- 実機起動にはコード署名が必須なので、Xcodeの自動開発署名のみ許容する。公証は行わない。
- 初期版ではPython/PyQt、G'MIC、動画・音声、印刷、自動更新、外部プロセス依存機能を対象外とする。
- 「プラグインを捨てる」は外部拡張機能を対象とする。ブラシ、ツール、画像入出力、DockerなどKrita本体機能を構成する内部プラグインは必要なものを静的リンクする。
- App Store、公式代替マーケットプレイス、一般配布、iPhone対応は対象外。

## 優先度

- **P0**: 次のマイルストーンを成立させるために必須。
- **P1**: Android版相当の主要利用体験に必要。
- **P2**: 初期版成立後に追加する機能または改善。

## マイルストーン一覧

| ID | マイルストーン | 成果物 | 目安 |
|---|---|---|---:|
| M0 | 方針固定とベースライン | 決定記録、機能表、既存ビルド確認 | 2～4日 |
| M1 | 再現可能なビルド基盤 | `flake.nix`、toolchain、Xcode検査 | 5～10日 |
| M2 | iOS向け最小依存セット | arm64/iOS静的ライブラリ群 | 10～20日 |
| M3 | Krita最小アプリのリンク | 起動可能な最小`.app` | 8～15日 |
| M4 | 内部プラグイン静的化 | 自動登録基盤、最小機能セット | 12～25日 |
| M5 | 実機起動と描画 | Pencilで描画できる実機ビルド | 10～20日 |
| M6 | ファイルとライフサイクル | Files連携、保存、復帰 | 8～15日 |
| M7 | Android版相当機能 | 主要ブラシ・ツール・Docker | 15～30日 |
| M8 | 安定化と性能 | 長時間利用可能な候補ビルド | 15～30日 |
| M9 | 再現可能な引き渡し | 1コマンドビルド、運用文書 | 5～10日 |

日数は単純加算しない。M2、M4、M5、M8がクリティカルパスである。

---

## M0: 方針固定とベースライン

### タスク

- [x] **P0** 対象ブランチ、Qt/KFのrevision、最低iPadOSバージョンを記録する。
- [x] **P0** Xcode、iOS SDK、Nixの要求バージョンを決める。
- [x] **P0** macOSまたは既存Androidビルドの手順を確認し、移植前の既知エラーを分離する。
- [x] **P0** Android版の機能を「必須・後回し・削除」に分類する。
- [x] **P0** 173件の`MODULE`定義（具体的な172ターゲットとテスト用テンプレート1件）をカテゴリ別に棚卸しし、初期版の静的リンク対象を選ぶ。
- [x] **P0** 必須依存と任意依存の一覧を機械可読な形で作る。
- [x] **P0** ADR（Architecture Decision Record）を作り、Nix/Xcode境界と静的リンク方針を記録する。
- [x] **P1** 既存Android固有コードのうち、iPadOSで再利用できるUI・タッチ対応を特定する。

### 完了条件

- [x] 初期機能セットと削除機能が明文化されている。
- [x] 必須依存、内部プラグイン、プラットフォームAPIの三つのリスク表がある。
- [x] Qt/KF/Xcode/iPadOSの組み合わせが一つに固定されている。

---

## M1: NixとXcodeによる再現可能なビルド基盤

### タスク

- [x] **P0** `flake.nix`と`flake.lock`を追加する。
- [x] **P0** `aarch64-darwin`用dev shellを作る。
- [x] **P0** CMake、Ninja、Python、pkg-config等のホストツールを固定する。
- [x] **P0** macOSホストツールとarm64/iOSターゲットライブラリを明確に分離する。
- [x] **P0** `CMAKE_SYSTEM_NAME=iOS`を設定するtoolchain/presetを追加する。
- [x] **P0** XcodeとiOS SDKのversionを検査し、不一致時に早期失敗させる。
- [x] **P0** deployment target、architecture、bitcode、visibility、dead stripping方針を固定する。
- [x] **P0** 実機用とSimulator用の出力ディレクトリを分離する。
- [x] **P1** ローカルNix binary cacheの利用手順を用意する。
- [x] **P1** CIなしでも実行できるビルドログ収集スクリプトを追加する。

### 完了条件

- [x] クリーンなshellから同じコンパイラ、SDK、CMake設定が選択される。
- [x] Mac用バイナリとiOS用ライブラリの混入を検査できる。
- [x] `nix develop`から最小のiOS Hello Worldをビルドできる。

---

## M2: iOS向け最小依存セット

### タスク

- [x] **P0** Qt 6 for iOSを取得またはソースビルドし、revisionと構成を固定する。
- [x] **P0** Qt Core/Gui/Widgets/Xml/Network/Svg/Concurrent/Sql/OpenGL系を検証する。
- [x] **P0** iOSで利用できないQt PrintSupportを必須依存から外す。
- [x] **P0** ECMと必須KDE Frameworksを静的ビルドする。
- [x] **P0** KF Config、WidgetsAddons、Codecs、Completion、CoreAddons、GuiAddons、I18n、ItemViews、ColorSchemeを個別検証する。
- [x] **P0** PNG、zlib、Boost、Immer、Zug、Lagerを構築する。
- [x] **P0** Eigen、Exiv2、LCMS2、xsimd、QuaZipを構築する。
- [x] **P0** FreeType、HarfBuzz、Fontconfig、libunibreakを構築する。
- [x] **P0** `try_run()`、ホスト実行コード生成器、pkg-config誤検出を修正する。
- [x] **P0** 各成果物を`file`、`lipo`、`otool`で検査し、iOS arm64以外を拒否する。
- [x] **P1** JPEGを追加する。
- [ ] **P1** 初期版に必要ならWebP/TIFFを追加する。
- [ ] **P2** OpenEXR/HEIF/JPEG XL/RAW/Popplerを個別に再評価する。

### 完了条件

- [x] 必須依存がすべてiOS arm64向けにリンク可能である。
- [x] Homebrewやホスト側`/usr/local`への暗黙依存がない。
- [x] 同じlock fileから依存物を再生成できる。

### 技術ゲート G1

KDE FrameworksまたはQt Widgets/OpenGLがiOS上で成立しない場合、Krita全体の作業を進めず、代替構成または対象機能縮小を判断する。

判定: **通過**。Qt Widgets/OpenGL、ECM、必須KF6、KConfigホストコード生成器を1本のiOS arm64アプリへ静的リンクできた。

---

## M3: Krita最小アプリのconfigure・compile・link

### タスク

- [ ] **P0** `APPLE`分岐を`IOS`と`APPLE AND NOT IOS`へ分離する。
- [ ] **P0** macOSパッケージング、RPATH、`.icns`、`-mmacosx-version-min`をiOSから除外する。
- [ ] **P0** `qt_add_executable()`または同等のiOS bundle生成へ切り替える。
- [ ] **P0** iOS用Info.plist、Bundle ID、向き、デバイス要件、アイコンを追加する。
- [ ] **P0** `krita_version`等の補助実行ファイルをiOSビルドから外す。
- [ ] **P0** PrintSupport、QProcess、Python、アップデータ、外部実行機能を条件付き無効化する。
- [ ] **P0** `libs/macosutils`とmacOS Objective-C++コードをiOSから分離する。
- [ ] **P0** 共有ライブラリを静的ライブラリまたはiOS対応frameworkへ変換する。
- [ ] **P0** 最小main windowとリソースを含む`.app`を生成する。
- [ ] **P1** 起動ログをOSLogまたは標準的な実機ログへ転送する。

### 完了条件

- [ ] 未署名またはad-hocの中間`.app`がリンクまで完了する。
- [ ] iOS SDKに存在しないAPIやmacOS frameworkへのリンクがない。
- [ ] 起動前の静的初期化でクラッシュしない。

---

## M4: Krita内部プラグインの静的化

### タスク

- [ ] **P0** `kis_add_library(... MODULE ...)`をiOS時に`STATIC`へ変換するCMake基盤を作る。
- [ ] **P0** KPlugin factoryを衝突なく静的登録する仕組みを作る。
- [ ] **P0** JSONメタデータをバイナリまたはリソースへ埋め込む。
- [ ] **P0** `Q_INIT_RESOURCE`相当を自動生成する。
- [ ] **P0** linker dead strippingからfactoryとリソースを保護する。
- [ ] **P0** 必要プラグインの一覧から登録コードとリンク対象を生成する。
- [ ] **P0** 最小セットとしてKRA、PNG、Pixel Brush、基本Tool、Layer Dockerを有効化する。
- [ ] **P1** JPEG/ORA、主要Brush、主要Tool、Brush Presets、Color Selectorを追加する。
- [ ] **P1** プラグイン単位でON/OFFできるiOS feature profileを作る。
- [ ] **P2** 任意フィルタとDockerを段階的に追加する。

### 完了条件

- [ ] 起動時に選択したプラグインだけが列挙・ロードされる。
- [ ] Pixel Brush、基本Tool、Layer Docker、KRA/PNG I/Oが利用可能である。
- [ ] 新しい静的プラグインを一覧へ追加するだけで組み込める。

### 技術ゲート G2

最小プラグインセットを静的ロードできなければ、個別factory登録またはコアへの直接組み込みへ方針変更する。

---

## M5: iPad実機起動と描画

### タスク

- [ ] **P0** Xcodeの自動開発署名を設定する。
- [ ] **P0** 実機インストールとログ取得をスクリプト化する。
- [ ] **P0** アプリ起動、main window表示、終了までを確認する。
- [ ] **P0** 最小キャンバスを作成し、指でストロークを描く。
- [ ] **P0** Apple Pencilの位置、筆圧、傾き、方位、接触状態を記録・検証する。
- [ ] **P0** Pencil描画と指ジェスチャーを分離する。
- [ ] **P0** undo/redo、pan、zoom、rotateを実装・確認する。
- [ ] **P0** 高DPI、Safe Area、画面回転を修正する。
- [ ] **P0** OpenGL/描画surfaceの作成、破棄、再作成を検証する。
- [ ] **P1** hover対応iPadでPencil hoverを検証する。
- [ ] **P1** キーボードショートカットを確認する。

### 完了条件

- [ ] 実機で新規キャンバスを作成し、Pencil筆圧付きで描画できる。
- [ ] pan/zoom/rotateと描画が競合しない。
- [ ] 10分間の連続描画でクラッシュや入力停止がない。

### 技術ゲート G3

主要対象iPadで安定したPencilイベントまたは描画surfaceが得られない場合、Qt patchまたはiOS native input bridgeを実装する。

---

## M6: ファイルアクセスとアプリライフサイクル

### タスク

- [ ] **P0** UIDocumentPicker/FilesアプリをQt/C++から利用するbridgeを作る。
- [ ] **P0** open/import/export/save/save-asの動線をiPadOS向けに整理する。
- [ ] **P0** security-scoped URLの開始、終了、bookmark保持を実装する。
- [ ] **P0** inbox、temporary、Documents、cacheの用途を分離する。
- [ ] **P0** KRA/PNG/JPEG/ORAの読み書きを実機で検証する。
- [ ] **P0** background移行前の保存・journal処理を実装する。
- [ ] **P0** foreground復帰時にcanvas/GPU/resourceを復元する。
- [ ] **P0** memory warningを受けて安全にcacheを解放する。
- [ ] **P0** 強制終了後のautosave recoveryを検証する。
- [ ] **P1** Filesから「共有/開く」でKritaへ渡すDocument Typeを設定する。
- [ ] **P1** iCloud Drive上のファイルで競合・遅延を検証する。

### 完了条件

- [ ] FilesからKRAを開き、編集して安全に保存できる。
- [ ] background/foregroundを20回繰り返してデータ消失やクラッシュがない。
- [ ] 強制終了後にautosaveから復旧できる。

---

## M7: Android版相当の主要機能

### 必須機能セット

- [ ] **P0** Pixel Brush、Eraser、基本Brush Presets。
- [ ] **P0** Layer追加・削除・並べ替え・可視性・opacity・blend mode。
- [ ] **P0** Undo/Redo、selection、move、transform、crop、fill、gradient、textの基本動作。
- [ ] **P0** KRA/ORA/PNG/JPEG import/export。
- [ ] **P0** Layer、Brush Presets、Tool Options、Advanced Color Selector Docker。
- [ ] **P0** canvas-only modeまたはiPad向け省スペース配置。
- [ ] **P1** Clone、Filter Brush、Colorize、Assistant等の主要ブラシ・ツール。
- [ ] **P1** 基本フィルタとgenerator。
- [ ] **P1** resource bundleのimport/export。
- [ ] **P1** Bluetooth/USBキーボード操作。
- [ ] **P2** アニメーションUI。ただし動画・音声exportは対象外。

### UI調整

- [ ] **P0** Android版のタッチ用設定をiOS profileとして再利用する。
- [ ] **P0** 小さすぎるmenu、dialog、slider、spinboxのtouch targetを修正する。
- [ ] **P0** modal dialogとソフトウェアキーボードの重なりを修正する。
- [ ] **P1** Split ViewとStage Managerでlayoutを検証する。
- [ ] **P1** 外部ディスプレイ接続時の挙動を確認する。

### 完了条件

- [ ] 定義したAndroid版相当のP0機能チェックリストをすべて通過する。
- [ ] 主要操作にマウスを必要としない。
- [ ] 初回起動から保存までの操作に行き止まりがない。

---

## M8: 安定化、性能、容量

### タスク

- [ ] **P0** Instrumentsでmemory、CPU、GPU、hangを計測する。
- [ ] **P0** 2K/4K/8Kキャンバスと複数レイヤーの上限を記録する。
- [ ] **P0** tile/cache/thread数をデバイスメモリに合わせて調整する。
- [ ] **P0** memory pressure時の段階的cache削減を実装する。
- [ ] **P0** 起動時間、初回brush表示、KRA保存時間の基準値を作る。
- [ ] **P0** 1時間連続描画テストを実行する。
- [ ] **P0** suspend/resume、回転、Split View、低ストレージの回帰テストを作る。
- [ ] **P0** static pluginとresourceを削減し、アプリ容量を確認する。
- [ ] **P0** crash logと再現手順を保存する運用を作る。
- [ ] **P1** Address Sanitizer/Undefined Behavior SanitizerをSimulatorまたは対応構成で実行する。
- [ ] **P1** Kritaの非GUI単体テストをiOS互換範囲で実行する。
- [ ] **P2** battery/thermal throttlingを長時間試験する。

### 完了条件

- [ ] 対象デバイスで1時間の描画・保存を完走する。
- [ ] 既知のデータ消失バグがない。
- [ ] P0回帰テストを連続3回通過する。
- [ ] サポートするキャンバスサイズとメモリ上限が文書化されている。

---

## M9: 再現可能な自前ビルドと運用

### タスク

- [ ] **P0** 新規checkoutからのbootstrap手順を自動化する。
- [ ] **P0** `nix build`で依存物を再生成できるようにする。
- [ ] **P0** configure、build、development sign、install、log取得を個別コマンドにする。
- [ ] **P0** Xcode/SDK更新時の検証手順を作る。
- [ ] **P0** upstream追従時のrebase/checklistを作る。
- [ ] **P0** 使用パッチ、削除機能、既知制約を文書化する。
- [ ] **P0** GPL/LGPL対象ソース、patch、build recipeを保持する。
- [ ] **P1** dependency SBOMとライセンス一覧を生成する。
- [ ] **P1** private binary cacheの復旧手順を記録する。

### 完了条件

- [ ] クリーンなforkから文書どおりに実機ビルドを再現できる。
- [ ] 別の開発セッションでも手作業の未記録操作を必要としない。
- [ ] 既知問題、対象外機能、対応端末条件がREADMEに記載されている。

---

## 初期プラグイン候補

正確なtarget名はM0で棚卸しして確定する。

### P0で残す

- KRA、ORA、PNG、JPEG import/export
- Pixel BrushとEraserに必要なpaintop
- Freehand、Line、Rectangle、Ellipse、Move、Transform、Crop、Fill、Gradient、Selection系tool
- Layer、Brush Presets、Tool Options、Advanced Color Selector docker
- 基本色管理とresource loader
- KRAで使用する基本filter/generator

### 初期版から外す

- Python/PyQt
- G'MIC
- PrintSupport
- FFmpeg/MLT/SDLと動画・音声export
- AppImage updater等の更新機能
- bug reportの外部process起動
- Qt Designer plugin
- X11/Wayland/Windows/macOS/Android固有platform plugin
- RAW、PDF、HEIF、JPEG XL、OpenEXR等の優先度が低いI/O
- 外部実行ファイルに依存する機能

## 横断的な完了基準

各タスクを完了扱いにするには、原則として次を満たす。

- [ ] コードまたは設定がforkにcommit可能な形で存在する。
- [ ] 再現コマンドが記録されている。
- [ ] 成功ログまたはテスト結果がある。
- [ ] 新しい手動前提がREADME/ADRに記録されている。
- [ ] macOS/Android側への意図しない回帰がない、または影響が明記されている。
- [ ] 一時的な回避策には削除条件と追跡TODOがある。

## 直近の実行順序

1. M0の対象version・機能セット・プラグイン棚卸しを確定する。
2. M1でflakeとiOS Hello Worldを成立させる。
3. M2では全依存を一度に作らず、Qt → KF → Krita必須C/C++ライブラリの順で追加する。
4. M3でプラグインなしの最小Krita shellをリンクする。
5. M4でKRA/PNG、Pixel Brush、Layer Dockerだけを静的登録する。
6. G1～G3を通過してからAndroid版相当機能を追加する。
