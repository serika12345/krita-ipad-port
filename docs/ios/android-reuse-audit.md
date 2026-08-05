# iPadOS port: Android分岐再利用の棚卸し

## 強制方針

Krita upstream本体へ加えるAndroid再利用差分は、既存のAndroid条件へ
iOSを追加する一行の条件変更に限定する。既存の処理本体は変更しない。

許可する変更形式は次の同等形だけである。

```cpp
#ifdef Q_OS_ANDROID
```

を

```cpp
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
```

へ変更する。または、除外条件について

```cpp
#ifndef Q_OS_ANDROID
```

を

```cpp
#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS)
```

へ変更する。CMakeについても、既存の`ANDROID`条件へ`IOS`を追加するだけの
同等な一行変更に限る。

この方針では、次を行わない。

- 共通helperの抽出、関数の移動、rename、class追加
- AndroidとiOSの処理を揃えるための既存処理本体の変更
- OS判定を新しいcapability abstractionへ置き換える変更
- guard変更と同時に行うnull check、ログ、同期方法などの改善
- 実機検証を理由にしたupstream本体の広範な非同期化

一行の条件追加だけで成立しない機能はAndroid流用扱いにしない。必要なら
iOS adapterを独立ファイルへ隔離するか、現状のiOS専用分岐を維持する。

## 調査範囲

Krita基準revision
`7173825999953623d28777a163a65b42a3f26f0a`から、棚卸し前HEAD
`b05bf0486821a82764f9b3e9e72a39548d874205`までの82コミット・309ファイルを
対象とした。

このうち123ファイルは`nix/ios`、44ファイルは`packaging/ios`、10ファイルは
`docs/ios`であり、差分量の大半はKrita本体処理ではなくiOSビルド・配備境界で
ある。

## 判定1: Android条件へiOSを追加するだけで流用できるもの

次の変更は既存Android/非Android処理本体を変更せず、条件だけを拡張している。
現在の方針に適合する。

| 対象 | 条件変更 | 状態 |
|---|---|---|
| Video Animation import | `!Q_OS_ANDROID`へ`!Q_OS_IOS`を追加 | 実装済み。両OSとも外部FFmpeg processを使わない。 |
| Main Windowのdesktop widget style列挙 | `!Q_OS_ANDROID`へ`!Q_OS_IOS`を追加 | 実装済み。mobileでdesktop style切替UIを作らない。 |
| TabletRelease後のmouse event再許可 | macOS/Android条件へiOSを追加 | 実装済み。処理本体は共通。 |
| pickerが返したURLへの拡張子後付け禁止 | macOS/Android条件へiOSを追加 | 実装済み。権限を持たないsibling URLを作らない。 |
| `krita_version`補助実行ファイル | `NOT ANDROID`へ`NOT IOS`を追加 | 実装済み。mobile bundleへ不要な実行ファイルを追加しない。 |
| Small Color Selectorの除外 | `NOT ANDROID`へ`NOT IOS`を追加 | 実装済み。既存plugin本体は変更しない。 |

現在のAndroid固有ブロックを再確認した結果、追加で安全にiOSを条件へ足せる
未対応箇所は確認できなかった。したがって、この棚卸しに基づくKrita本体の
追加修正は行わない。

## 判定2: 分岐追加なしで既に同じ実装を使っているもの

次はAndroid分岐の流用ではなく、元からplatform-neutralなKrita pluginまたは
処理である。iOS側は主として依存構築、静的リンク、登録、runtime data同梱を
担当する。

- Brush、PaintOp、Tool、Docker、Filter、通常Generator
- KRA、PNG、JPEG、ORA
- CSV、SVG、QImageIO、XCF、PSD、QML、TGA、Heightmap、Brush、Spriter、
  KRZ、RGBE
- TIFF、OpenEXR、JPEG 2000、WebP
- GIF、HEIF、JPEG XL、RAW、PDF
- MyPaint、metadata、flake shapes、color-space extensions、Resource Manager
- SeExpr generator

これらの機能本体へ、iOS用の追加分岐や共通helperを導入してはいけない。

## 判定3: Android条件の追加だけでは流用できないもの

| 対象 | Android側 | iOS側 | 判定 |
|---|---|---|---|
| Application pause/autosave通知 | Activity、JNI、foreground service | UIApplication通知、background task | `autoSaveOnPause()`呼出しが似ていても共通helperへ抽出しない。native adapterを分離したまま維持する。 |
| Native file picker | Storage Access Framework URI | UIDocumentPicker、security-scoped URL | MIME selectorを含め、guard変更だけでは同じ処理にならない。現状を維持する。 |
| Plugin loading | ABI別`lib_krita*`動的load | 単一実行ファイルへの静的登録 | Android branchをiOSへ拡張しない。 |
| Stylus初回接触 | Android QPA/S Pen event順序 | hover/EnterなしのApple Pencil press | AndroidのEnter除外やTouchCancel workaroundへiOSを追加しない。 |
| 補助stylus action | S Pen plugin/JNI | `UIPencilInteraction` | actionが同じでもbridgeは共有しない。 |
| Kinetic scrolling | Android touchとJNI long-press timeout | synthesized left-mouseとviewport gesture | Android条件へiOSを追加しない。 |
| Memory pressure | Android adapterは未実装 | UIKit memory warningとjetsam向け上限 | iOSの上限をAndroidへ共有しない。 |
| Fill Layer modal dialog | Androidでは同期`exec()`が成立 | Qt iOSの同期QPA配送で再入する | Android分岐の共有では解決しない。iOS非同期分岐を維持する。 |
| OpenColorIO/LUT Docker | Android buildでは明示的に除外 | desktop実装をiOS GLES向けに構築 | Android実装の流用ではない。現在のiOS限定build設定を維持する。 |
| Recorder/animation export | Android media encoder | iOS encoderなし | Android native backendをiOS条件へ広げない。 |
| SVG Text | Android window/IME処理あり | Qt Quick/QML未搭載、iOS IME未検証 | dependency追加だけでもguard変更だけでも成立しない。 |
| Text Properties | Android/desktop Qt Quick UI | Qt Quick/QML未搭載 | 現状は除外を維持する。 |
| Storyboard/printing | Android/desktop PrintSupport | iOS Qt profileにPrintSupportなし | 現状は除外を維持する。 |
| Splash、Preferences、ComboBox、item-view keyboard | Androidとは異なるQt/UI挙動 | UIKit scene、UIPicker、iOS IME | iOS専用分岐を維持する。 |

## 判定4: upstream追従方針上、local cleanupしてはいけないもの

次は技術的には共通化または一般化できても、このrepositoryでは実施しない。

- Android/iOS pause保存処理の共通関数化
- Android/iOS MIME selectorやfile picker state machineの統合
- Pencil/S Pen action dispatcherの抽出
- Fill Layer非同期処理の全platform共通化
- LUT Dockerの`IOS`判定を新しいGLES capability判定へ変更
- `KisOpenGLIOSCompat.h`のAndroid/GLES一般化
- iOS UI workaroundのmobile共通policy化
- node creationのqueued connection削除または再構成

LibRawのheap化、plugin factory symbol、IPTC初期化、MyPaint登録、CMake Find module
など、移植中に見つかったplatform-neutralな問題は、必要な現行patchを維持する
場合でも「Android流用のためのlocal cleanup」として拡張しない。一般修正として
採用するなら、別途upstreamへ提案し、upstream側の変更として取り込む。

## 今後の変更判定手順

新しい候補は次をすべて満たす場合だけ実装する。

1. upstreamに既存のAndroid分岐がある。
2. iOSでも分岐内の全処理が一行も変更せず成立する。
3. Android固有Java/JNI/API、path、lifecycle、event orderingを参照しない。
4. 変更は条件行への`Q_OS_IOS`追加だけで完結する。
5. iOS実機確認に加え、Androidの挙動を変えないことが明白である。

一つでも満たさない場合は修正せず、この文書と`TODO.md`へ未対応理由を記録する。

## 検証状態

この棚卸しは実装境界の判定であり、実機検証の代替ではない。非同期Fill Layer、
LUT Docker、SeExprの操作確認は引き続き`TODO.md`で追跡する。実機ビルド
`20260805102358`でnode creationのqueued connectionだけを除くと、Pencil release中の
`QGestureManager::getState()`でクラッシュが再現した。したがって、queued connectionは
node／UI変更をtablet/mouse配送完了後へ送るために必要であり、nested event loopを除く
非同期Fill Layer処理とは重複しない。
