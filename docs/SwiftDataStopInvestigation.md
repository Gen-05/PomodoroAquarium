# SwiftData停止の調査（2026-11-02）

## 状態

根因未特定。クラッシュの修正完了とはしていない。基点はcleanなHEAD `41d135b`。
ユーザー提供の停止履歴を先に読み、確率表示が原因とは仮定していない。
iPhoneの停止と、別のiPadシミュレータのCPU 103%表示は別件として扱う。

## 履歴とコードから確認したこと

- 実機の履歴はSwiftData内部タイマー → 保存通知 → `_SwiftData_SwiftUI` → SwiftDataのEXC_BREAKPOINT。Fatal error本文や関数名がないため、これだけで寿命・モデル無効化・Framework側不具合のどれかは決められない。
- AppはSwiftUIの`.modelContainer(for:...)`で最上位へContainerを注入する。これはAppleが示す標準構成であり、明示的な所有プロパティがないことだけでは寿命不具合と断定できない。
- Home/水槽タブ/MainTabのQueryは環境のContextを利用する。魚の座標・深度・アニメーションの進行は共有の実行時セッションにあり、通常の毎フレーム更新はモデルを保存しない。
- MainTabの1秒tickは日次リセットを確認するが、同じ日なら各サービスは変更なしで戻る。Home表示時の集中時間キャッシュ同期はPlayerを変更し得るため、その後の自動保存は発生し得る。
- 直近コミットはHomeに確定記録のQueryと表示を追加。確率計算は読み取りであり、無操作時に報酬・記録を追加しない。このQueryを含む実機固有条件は未排除。
- 編集は切り離したモデルを利用する。試し置き・各Previewは所有する独立Container/Contextを使う。Previewリセット内での削除はその独立ストア内に限定される。Previewが実機停止前に使われたかは不明。
- Appの通常経路でPlayer/所有魚を削除する周期処理はない。魚表示のキャッシュは配置IDの変更に追従する。これにより既存実機データの無効参照が完全に否定できるわけではない。

Appleの説明: [ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext)、[保存と自動保存](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches)。タイマーからの自動保存通知自体は仕様で、通知があることだけを故障原因とはしない。

## 今回追加したDEBUG診断

- `SwiftDataStopDiagnostics.swift`: Context/Containerの弱参照、登録元、保存前後通知、保存対象のモデル型・件数、保存呼出スタック、30秒ごとの生存/変更状態を記録。
- Appでrootを登録。MainTabの既存tickを利用し、新しいTimer/反復Taskは追加しない。
- Home/Aquariumの出現・離脱、QueryモデルのContext不一致・削除状態を記録。
- Core/装飾チュートリアル/ショップ試し置き/日次受取Previewを別の登録元として識別。
- Context/Container/モデルを長期保持せず、診断内ではfetch/save/rollbackやモデル変更をしない。通知を受けてUIを再描画する状態も追加しない。
- 編集/試し置きでは切り離したPlayerを使うため、`Aquarium.appear.copy=true`の`detached=1`は正常に起こり得る。単にdetached件数があるだけで不具合とは判定しない。
- 未登録Contextの通知はcontext=0で記録し、そのContextの属性へ追加アクセスしない。
- すべてDEBUG限定。Releaseでは診断コード・記録処理を含めない。

### ログの場所

XcodeのConsole/Console.appで `[SwiftDataStop]` を確認できる。
アプリのContainer内の `Library/Caches/swiftdata-stop-debug.log` にも保存する（最大約256KB。上限時は診断ログのみ切り詰める）。
XcodeのDevices and Simulatorsで対象アプリのContainerをダウンロードすれば取り出せる。アプリのデータ削除・再インストール・初期化は不要。
ログは複数起動分を含むことがあり、`launch pid=... os=...`ごとに区切って読む。

## 確認結果

- 診断がcustom Contextを保持しないテスト: 成功。
- 保存通知・モデル参照の診断が残高/所持/配置ID/記録を変更せず、再保存しないテスト: 成功。
  - `/private/tmp/SwiftDataIdleVerified.xcresult`内のUnit 2件。UI準備の失敗とは区別する。
- iPhone 17 Pro / iOS 26.5 Simulator、通常のSQLite・自動保存・Query、正式保存済みナンヨウハギ3匹:
  - Homeで90秒無操作: 継続、停止なし。
  - 水槽タブで90秒無操作: 継続、停止なし。
  - `/private/tmp/SwiftDataIdleSavedAquarium.xcresult`: 対象UI 1件成功。
  - App.root/Home/水槽/MainTabのContextは同一。Containerは生存。観測したモデルにforeign/deleted参照なし。
  - 起動/画面表示後のPlayer残変更は自動保存された。その後の30秒間隔の観測はhasChanges=falseで、待機中に保存回数が増え続ける現象なし。
- 初期のUI準備は自動非表示と保存確認の想定差で失敗した。アプリのSwiftData停止の再現ではない。
- 既存の実機ストアは取得・編集していない。実機での再現、実機の既存集中記録を持つ条件、長時間、20匹、Preview利用後、バックグラウンド復帰後の再現は未確認。

DEBUGログ自体でわずかなタイミング変化は起こり得る。今回の非再現を修正完了の証拠にはしない。

## 変更ファイル

- `Services/SwiftDataStopDiagnostics.swift`: 弱参照・通知・生存/変更状態の診断。
- `PomodoroAquariumApp.swift`, `Views/MainTabView.swift`: root登録と既存tickからの観測。
- `Views/HomeView.swift`, `Views/AquariumView.swift`: 画面の出入り、モデル所属の記録。
- `Views/RewardPreviewView.swift`, `Views/DailyFishClaimPreviewView.swift`, `ViewModels/DecorationTutorialPreviewSession.swift`, `ViewModels/ShopDecorationPreviewSession.swift`: 独立Previewの登録。
- `PomodoroAquariumTests/SwiftDataStopDiagnosticsTests.swift`: 診断の弱参照・非変更確認2件。
- `PomodoroAquariumUITests/PomodoroAquariumUITests.swift`: 専用Simulatorの無操作確認1ケース。
- この調査記録。

## 次の実機確認

同じDEBUGビルドで通常のHome/水槽を操作せず表示する。再発した場合、上記ログ、表示していたタブ、表示からの時間、同じ起動中のPreview/試し置き使用有無を照合する。
停止中のXcodeが残っていれば、再開する前にFatal error本文と完全なスレッド履歴を保存する。読み取り用のLLDB例は `thread backtrace all -c 60`、`image lookup -a $pc`。`expr`でモデルを操作したり、根拠なく実行再開・リセットしない。
このセッションでは既存の実機停止プロセスの追加LLDB情報は取得できなかった。
