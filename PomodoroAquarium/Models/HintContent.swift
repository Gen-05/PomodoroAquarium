import Foundation
import CoreGraphics

/// 読み物専用。ユーザーの状態やチュートリアルの進行は保持しない。
enum HintTopic: String, CaseIterable, Identifiable {
    case starting, categories, focusRules, statistics, fish, aquarium, decorations, shop
    var id: String { rawValue }

    var title: String {
        switch self {
        case .starting: "集中の始め方"
        case .categories: "集中カテゴリー"
        case .focusRules: "集中中のルール"
        case .statistics: "統計"
        case .fish: "魚の獲得と確認"
        case .aquarium: "水槽の編集"
        case .decorations: "装飾の使い方"
        case .shop: "ショップと背景"
        }
    }

    var subtitle: String {
        switch self {
        case .starting: "ポモドーロ・カウントダウン・ストップウォッチ"
        case .categories: "選択・追加・記録の振り返り"
        case .focusRules: "画面を離れたとき・操作UI・減光"
        case .statistics: "表示期間・グラフの選択・詳細・カテゴリ別"
        case .fish: "獲得条件・図鑑・獲得履歴"
        case .aquarium: "魚の追加・収納・保存・キャンセル"
        case .decorations: "配置・移動・重なり順・沈没船"
        case .shop: "購入確認・試し置き・背景の変更"
        }
    }

    var symbol: String {
        switch self {
        case .starting: "timer"
        case .categories: "tag"
        case .focusRules: "moon"
        case .statistics: "chart.bar.fill"
        case .fish: "fish.fill"
        case .aquarium: "pencil"
        case .decorations: "leaf"
        case .shop: "storefront.fill"
        }
    }

    var guides: [HintGuide] {
        switch self {
        case .starting:
            [
                guide("homeStart", "集中画面を開く", [
                    Self.page("集中画面を開く", .homeStart, "ホームの「はじめよう」を押すと、集中方法や時間を選ぶ画面が開きます。", "start")
                ]),
                guide("modes", "集中方法を選ぶ", [
                    Self.page("ポモドーロ", .timerPomodoro, "「ポモドーロ」は集中と休憩をセットで繰り返す方法です。時間とセット数は歯車から設定できます。", "mode"),
                    Self.page("タイマー", .timerCountdown, "「タイマー」は設定した時間をカウントダウンします。歯車から集中する時間を決めます。", "mode"),
                    Self.page("ストップウォッチ", .timerStopwatch, "「ストップウォッチ」は経過時間を数えます。終了時刻を決めずに始め、自分のタイミングで終了できます。", "mode")
                ]),
                guide("timeSettings", "時間を設定する", [
                    Self.page("時間設定を開く", .timerPomodoro, "時間の横にある歯車を押すと、選んだ集中方法の時間設定が開きます。ストップウォッチには時間設定はありません。", "settings"),
                    Self.page("時間とセット数を保存する", .timeSettings, "ポモドーロは集中時間・休憩時間・セット数を設定し、「保存」を押します。タイマーでは集中時間だけを設定します。", "save")
                ]),
                guide("startPause", "集中を開始・一時停止する", [
                    Self.page("集中を始める", .timerPomodoro, "方法や時間を決めたら「START」を押します。開始演出が終わると計測が始まります。", "start"),
                    Self.page("一時停止する", .timerRunning, "計測を止めたいときは「一時停止」を押します。操作が隠れている場合は、先に画面をタップして表示します。", "pause")
                ]),
                guide("resumeFinish", "再開・終了して報酬を見る", [
                    Self.page("続きから再開する", .timerPaused, "一時停止中に「再開する」を押すと、続きから計測します。一時停止中の時間は集中時間に入りません。", "resume"),
                    Self.page("自分で集中を終了する", .timerPaused, "「終了する」を押し、確認画面で終了を選ぶと計測を終えます。ストップウォッチも、この操作で終了します。", "finish"),
                    Self.page("報酬を確認する", .studyFinished, "終了画面の「報酬を見る」を押すと、今回の集中による報酬を確認できます。", "reward")
                ])
            ]
        case .categories:
            [
                guide("select", "カテゴリーを選ぶ", [
                    Self.page("カテゴリー欄を開く", .timerPomodoro, "集中方法の上にあるカテゴリー欄を押します。何に集中するかを、始める前に選べます。", "category"),
                    Self.page("集中する内容を選ぶ", .categories, "一覧のカテゴリーを押すと選択され、集中画面へ戻ります。集中の記録は、このカテゴリーで振り返れます。", "reading")
                ]),
                guide("create", "カテゴリーを追加する", [
                    Self.page("カテゴリーの追加を開く", .categories, "カテゴリー一覧の「カテゴリを追加」を押すと、自分のカテゴリーを作れます。", "add"),
                    Self.page("名前と色を決める", .categoryCreate, "名前を入力し、「カラーを選択」から色を決めます。「保存」を押すとカテゴリーが追加されます。", "name")
                ]),
                guide("records", "カテゴリー別に振り返る", [
                    Self.page("カテゴリー別の記録", .statistics, "下部の「統計」を開き、下へスクロールすると「カテゴリ別」で集中時間の内訳を確認できます。")
                ])
            ]
        case .focusRules:
            [
                guide("stay", "集中中はアプリを開いておく", [
                    Self.page("水族館で集中する", .focusRules, "集中を始めたら、このアプリを開いたまま過ごします。集中画面のルールボタンからも説明を確認できます。")
                ]),
                guide("away", "画面を離れた場合の扱い", [
                    Self.page("画面を離れるときの注意", .focusRules, "他のアプリへの移動や画面ロックも離脱の対象です。3分でお知らせし、5分以上離れると今回の集中は終了します。")
                ]),
                guide("display", "減光・操作UIの再表示", [
                    Self.page("操作がないと集中表示へ", .focusDim, "集中中に10秒間操作しないと、操作UIが隠れて水槽がゆっくり暗くなります。時間表示の明るさは保たれます。"),
                    Self.page("画面をタップして操作を表示", .timerRunning, "集中表示中に画面をタップすると、操作UIと水槽の明るさが戻ります。一時停止などは、再表示してから操作します。", "pause")
                ])
            ]
        case .statistics:
            [
                guide("overview", "統計の見方", [
                    Self.page("表示期間を切り替える", .statisticsOverview, "「日間・週間・月間・年間」を切り替えると、選んだ期間の集中時間とグラフを確認できます。", "period"),
                    Self.page("グラフから記録を選ぶ", .statisticsSelection, "棒グラフをタップすると、日間は時間帯、週間・月間は日、年間は月の記録を選べます。記録のない場所は選択されません。", "chart"),
                    Self.page("「詳細を見る」を開く", .statisticsSelection, "記録を選ぶと「詳細を見る」が現れます。押すと、選んだ時間帯・日・月の詳細記録が開きます。", "detail"),
                    Self.page("集中方法の内訳を確認する", .statisticsDetail, "「集中方法」ではポモドーロ・タイマー・ストップウォッチごとの時間を確認できます。「カテゴリ」には内訳が表示されます。"),
                    Self.page("各セッションを確認する", .statisticsSessions, "下へスクロールすると「セッション」で各回の時刻・集中時間・カテゴリー・集中方法を確認できます。"),
                    Self.page("カテゴリー別の割合を見る", .statistics, "「カテゴリ別」まで下へスクロールすると、選択中の期間の集中時間をカテゴリーごとの割合で確認できます。")
                ])
            ]
        case .fish:
            [
                guide("progress", "魚の獲得条件", [
                    Self.page("集中時間をためる", .home, "当日の集中時間を合算し、25分ごとに魚を1匹獲得できます。休憩と一時停止の時間は含みません。", "progress")
                ]),
                guide("limit", "今日の獲得数と上限", [
                    Self.page("本日の獲得状況を確認", .home, "ホームで今日の獲得数と上限、次の魚までの進み具合を確認できます。25分未満の端数は翌日へ持ち越しません。", "progress")
                ]),
                guide("rarity", "珍しい魚に出会うには", [
                    Self.page("昨日の集中時間が影響", .home, "前日の集中時間に応じて、珍しい魚に出会う確率が上がります（180分で上限）。ホームの「昨日」で確認できます。", "summary")
                ]),
                guide("reward", "集中後の報酬を確認", [
                    Self.page("「報酬を見る」を押す", .studyFinished, "集中が終わったら「報酬を見る」を押します。獲得条件や当日の上限に応じた報酬が表示されます。", "reward")
                ]),
                guide("book", "図鑑と所持数", [
                    Self.page("図鑑で魚を確認", .book, "「その他」→「図鑑」で、出会った魚と所持数を確認できます。所持している魚を押すと詳細が開きます。")
                ]),
                guide("history", "獲得履歴", [
                    Self.page("出会った魚を振り返る", .history, "「その他」→「獲得履歴」で、獲得した魚や日時を確認できます。まだ獲得していない場合は空の表示になります。")
                ])
            ]
        case .aquarium:
            [
                guide("edit", "水槽の編集を始める", [
                    Self.page("「編集」から始める", .aquarium, "水槽画面の「編集」を押し、確認で「編集する」を選びます。魚・装飾・背景をここから編集できます。", "edit")
                ]),
                guide("addFish", "魚を水槽へ追加する", [
                    Self.page("魚の一覧を開く", .editorHeader, "編集画面の「魚」を押すと、所持している魚の一覧が開きます。", "fish"),
                    Self.page("所持している魚を追加", .fishLibrary, "「追加する」で魚を押すと水槽へ追加されます。全体で20匹まで配置でき、同じ種類も複数配置できます。", "add")
                ]),
                guide("storeFish", "魚を水槽から戻す", [
                    Self.page("魚を収納する", .fishStorage, "「水槽にいる魚」で個体の「水槽から戻す」を押します。所持数は減らず、「追加する」から再配置できます。", "store")
                ]),
                guide("undoRedo", "元に戻す・やり直す", [
                    Self.page("直前の操作を元に戻す", .editorHeader, "左向きの矢印を押すと、編集中の操作を元に戻せます。保存前の配置を調整するときに使います。", "undo"),
                    Self.page("戻した操作をやり直す", .editorHeader, "右向きの矢印を押すと、元に戻した操作をやり直せます。操作できないときはボタンが薄くなります。", "redo")
                ]), saveGuide, cancelGuide
            ]
        case .decorations:
            [
                guide("add", "装飾を追加する", [
                    Self.page("装飾の一覧を開く", .editorHeader, "ショップで購入した装飾は、編集画面の「装飾」から配置できます。購入しただけでは水槽に置かれません。", "decorations"),
                    Self.page("「追加する」から配置", .decorationLibrary, "「追加する」で種類を選び、所持している装飾を押します。追加した装飾は水槽内で選択されます。", "add")
                ]),
                guide("move", "装飾を移動する", [
                    Self.page("選択してドラッグ", .decorationSelected, "水槽内の装飾をタップして選び、そのままドラッグすると位置を動かせます。沈没船は固定配置のためドラッグできません。", "plant")
                ]),
                guide("nudge", "位置を微調整する", [
                    Self.page("「微調整」を開く", .decorationSelected, "装飾を選んで「微調整」を押します。重なり順とは別に、装飾を置く位置を少しずつ調整します。", "nudge"),
                    Self.page("左右・奥・手前へ移動", .decorationNudge, "矢印で左・右・奥・手前へ位置を動かします。奥や手前への移動では、接地と奥行きの見え方も変わります。", "arrows")
                ]),
                Self.stackingGuide,
                guide("facing", "対応する装飾の向きを変える", [
                    Self.page("左右の向きを切り替える", .chestFacing, "宝箱など対応する装飾を選び、左右矢印のボタンを押すと向きが変わります。向き変更に非対応の装飾には表示されません。", "facing")
                ]),
                guide("store", "装飾を水槽からしまう", [
                    Self.page("収納して、また使う", .decorationSelected, "選択した装飾の「水槽からしまう」を押すと収納します。所持品には残るので、購入し直さず再配置できます。", "store")
                ]),
                guide("shipwreck", "沈没船の固定配置", [
                    Self.page("「左奥」「右奥」を切り替える", .shipwreck, "沈没船は水槽に1隻までで、「左奥」「右奥」の固定配置です。ドラッグ・微調整・重なり順は使いません。", "right")
                ]), saveGuide, cancelGuide
            ]
        case .shop:
            [
                guide("purchase", "商品を確認して購入する", [
                    Self.page("商品を選ぶ", .shop, "ショップの商品ボタンを押すと購入確認が開きます。装飾は繰り返し購入でき、沈没船と背景は買い切りです。", "purchase"),
                    Self.page("内容を確認して購入を確定", .purchaseConfirmation, "画像・価格・購入後の残高を確認し、「購入を確定」を押すと購入します。キャンセルではコインは減りません。", "confirm")
                ]),
                guide("trial", "装飾を自分の水槽で試す", [
                    Self.page("購入前に試し置き", .purchaseConfirmation, "装飾の購入確認で「自分の水槽で試す」を押します。コイン不足でも使え、購入や正式保存はされません。", "trial"),
                    Self.page("商品を動かして比べる", .trial, "試す商品だけをドラッグ・微調整できます。重なり順や、対応商品の向きも試せます。本番の配置には影響しません。", "nudge"),
                    Self.page("購入確認へ戻る", .trialClose, "「閉じる」を押すと、同じ商品の購入確認へ戻ります。試した位置は保存されず、購入も実行されません。", "close")
                ]),
                guide("purchased", "「購入済み」の商品", [
                    Self.page("購入済みは追加購入できない", .purchasedBackground, "沈没船と背景は、所持すると「購入済み」になります。沈没船を収納しても購入済みは解除されません。", "purchased")
                ]),
                guide("backgrounds", "背景を購入する", [
                    Self.page("背景は種類ごとの買い切り", .backgroundShop, "「背景」では深い海・サンゴ礁を各3,000コインで購入できます。ベーシック海底は最初から使えます。")
                ]),
                guide("selectBackground", "購入した背景へ変更する", [
                    Self.page("編集画面の「背景」を開く", .editorHeader, "背景を購入しても、表示中の背景は変わりません。水槽の編集画面から「背景」を開いて切り替えます。", "background"),
                    Self.page("使用できる背景を選ぶ", .backgroundSelection, "ベーシックと購入済みの背景を選べます。鍵と「ショップで購入」が付く背景は、先にショップで購入してください。")
                ]), saveGuide
            ]
        }
    }

    private var saveGuide: HintGuide {
        guide("save", "編集を保存する", [
            Self.page("「完了」で保存", .editorHeader, "編集ができたら「完了」を押して保存します。保存された魚・装飾・背景が、通常の水槽へ反映されます。", "save")
        ])
    }
    private var cancelGuide: HintGuide {
        guide("cancel", "編集の変更を破棄する", [
            Self.page("「×」で編集を閉じる", .editorHeader, "変更を残さないときは「×」を押します。すぐには破棄されず、確認画面が表示されます。", "cancel"),
            Self.page("破棄するか確認する", .editorDiscard, "「変更を破棄」を選ぶと、編集中の変更を取り消します。「編集を続ける」なら編集へ戻れます。", "discard")
        ])
    }
    static let stackingGuide = HintGuide(id: "decorations.stacking", title: "装飾の重なり順", pages: [
        Self.page("装飾の重なり順", .stackingMenu, "装飾を選んで「重なり順」を押すと、重なった装飾の前後を変更できます。", "menu"),
        Self.page("前後を切り替える", .stackingControls, "左側の2つで奥へ、右側の2つで手前へ重なり順を変えます。薄いボタンは、その方向へ動かせない状態です。", "controls")
    ])
    private func guide(_ id: String, _ title: String, _ pages: [HintGuidePage]) -> HintGuide {
        HintGuide(id: "\(rawValue).\(id)", title: title, pages: pages)
    }
    private static func page(_ title: String, _ image: HintScreenshot, _ explanation: String, _ target: String? = nil) -> HintGuidePage {
        HintGuidePage(title: title, image: image, explanation: explanation, target: target)
    }

}

struct HintGuide: Identifiable {
    let id: String
    let title: String
    let pages: [HintGuidePage]
}

struct HintGuidePage {
    let title: String
    let image: HintScreenshot
    let explanation: String
    var target: String?
}

/// 実画面スクリーンショットと、画像内で正規化した操作箇所だけを保持する。
struct HintScreenshot {
    let assetName: String
    let aspectRatio: CGFloat
    var targets: [String: CGRect] = [:]
}
