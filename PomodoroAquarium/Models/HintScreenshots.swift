import Foundation
import CoreGraphics

/// 隔離した撮影環境の実画面。画像内の操作位置を0...1で保持する。
extension HintScreenshot {
    static let aquarium = Self(assetName: "hint_aquarium", aspectRatio: 1.747826087,
        targets: ["edit": CGRect(x: 0.778192397, y: 0.080434783, width: 0.193200638, height: 0.152173913)])
    static let backgroundSelection = Self(assetName: "hint_background_selection", aspectRatio: 0.945882353,
        targets: [:])
    static let backgroundShop = Self(assetName: "hint_background_shop", aspectRatio: 0.758490566,
        targets: [:])
    static let book = Self(assetName: "hint_book", aspectRatio: 0.855319149,
        targets: [:])
    static let categories = Self(assetName: "hint_categories", aspectRatio: 0.797619048,
        // 1206×1512の切り抜き画像内の行矩形。画面座標からの固定オフセットは使わない。
        targets: ["add": CGRect(x: 70.0 / 1206, y: 552.0 / 1512, width: 1066.0 / 1206, height: 151.0 / 1512),
                  "reading": CGRect(x: 70.0 / 1206, y: 1020.0 / 1512, width: 1066.0 / 1206, height: 148.0 / 1512)])
    static let categoryCreate = Self(assetName: "hint_category_create", aspectRatio: 0.797619048,
        targets: ["color": CGRect(x: 0.058117373, y: 0.659924583, width: 0.883765253, height: 0.140981600), "name": CGRect(x: 0.096334249, y: 0.378596436, width: 0.807331502, height: 0.041913449), "save": CGRect(x: 0.798569342, y: 0.177919924, width: 0.133759065, height: 0.068585643)])
    static let chestFacing = Self(assetName: "hint_chest_facing", aspectRatio: 1.631935047,
        targets: ["facing": CGRect(x: 0.398009950, y: 0.097428958, width: 0.109452736, height: 0.211096076)])
    static let decorationLibrary = Self(assetName: "hint_decoration_library", aspectRatio: 0.788235294,
        targets: ["add": CGRect(x: 0.039800995, y: 0.311764706, width: 0.445273632, height: 0.316993444)])
    static let decorationNudge = Self(assetName: "hint_decoration_nudge", aspectRatio: 1.805389222,
        targets: ["arrows": CGRect(x: 0.256218905, y: 0.107784431, width: 0.483416252, height: 0.233532934)])
    static let decorationSelected = Self(assetName: "hint_decoration_selected", aspectRatio: 1.805389222,
        targets: ["nudge": CGRect(x: 0.169154229, y: 0.107784431, width: 0.189054726, height: 0.233532934), "plant": CGRect(x: 0.660087198, y: 0.410405540, width: 0.177832061, height: 0.481584129), "store": CGRect(x: 0.577114428, y: 0.107784431, width: 0.373134328, height: 0.233532934)])
    static let editorDiscard = Self(assetName: "hint_editor_discard", aspectRatio: 0.592047128,
        targets: ["discard": CGRect(x: 0.509950249, y: 0.515463918, width: 0.348258706, height: 0.070692194)])
    static let editorHeader = Self(assetName: "hint_editor_header", aspectRatio: 2.115789474,
        targets: ["background": CGRect(x: 0.356965174, y: 0.050000000, width: 0.131840796, height: 0.372806991), "cancel": CGRect(x: 0.606135999, y: 0.052631579, width: 0.109452698, height: 0.252631579), "decorations": CGRect(x: 0.197761194, y: 0.050000000, width: 0.131840796, height: 0.372807071), "fish": CGRect(x: 0.038557214, y: 0.050000000, width: 0.131840796, height: 0.372807071), "redo": CGRect(x: 0.534825871, y: 0.557894737, width: 0.039800995, height: 0.082456142), "save": CGRect(x: 0.745439444, y: 0.052631579, width: 0.214759561, height: 0.252631579), "undo": CGRect(x: 0.425373134, y: 0.557894737, width: 0.039800995, height: 0.082456142)])
    static let fishLibrary = Self(assetName: "hint_fish_library", aspectRatio: 0.788235294,
        targets: ["add": CGRect(x: 0.039800995, y: 0.117647059, width: 0.460199005, height: 0.062745098), "placed": CGRect(x: 0.500000000, y: 0.117647059, width: 0.460199005, height: 0.062745098)])
    static let fishStorage = Self(assetName: "hint_fish_storage", aspectRatio: 0.788235294,
        targets: ["store": CGRect(x: 0.752072968, y: 0.483006536, width: 0.168325041, height: 0.028104575)])
    static let focusDim = Self(assetName: "hint_focus_dim", aspectRatio: 0.820408163,
        targets: [:])
    static let focusRules = Self(assetName: "hint_focus_rules", aspectRatio: 1.435714286,
        targets: [:])
    static let history = Self(assetName: "hint_history", aspectRatio: 1.057894737,
        targets: [:])
    static let home = Self(assetName: "hint_home", aspectRatio: 4.638461538,
        targets: ["progress": CGRect(x: 0.038557214, y: 0.190384615, width: 0.223051403, height: 0.426923077), "summary": CGRect(x: 0.279021559, y: 0.190384615, width: 0.442786070, height: 0.426923077)])
    static let homeStart = Self(assetName: "hint_home_start", aspectRatio: 2.275471698,
        targets: ["start": CGRect(x: 0.138308454, y: 0.401509411, width: 0.723383054, height: 0.291320801)])
    static let purchaseConfirmation = Self(assetName: "hint_purchase_confirmation", aspectRatio: 0.555248619,
        targets: ["cancel": CGRect(x: 0.401326700, y: 0.761049724, width: 0.198175788, height: 0.028084715), "confirm": CGRect(x: 0.371475954, y: 0.683241252, width: 0.257877280, height: 0.047421731), "trial": CGRect(x: 0.311774461, y: 0.605432781, width: 0.376451078, height: 0.047421731)])
    static let purchasedBackground = Self(assetName: "hint_purchased_background", aspectRatio: 0.758490566,
        targets: ["purchased": CGRect(x: 0.069651741, y: 0.689937107, width: 0.385572139, height: 0.064779874)])
    static let shipwreck = Self(assetName: "hint_shipwreck", aspectRatio: 0.957142857,
        targets: ["left": CGRect(x: 0.049751244, y: 0.744444444, width: 0.159203980, height: 0.123809524), "right": CGRect(x: 0.218905473, y: 0.744444444, width: 0.159203980, height: 0.123809524)])
    static let shop = Self(assetName: "hint_shop", aspectRatio: 0.758490566,
        targets: ["purchase": CGRect(x: 0.069651741, y: 0.689937107, width: 0.385572139, height: 0.064779874)])
    static let statistics = Self(assetName: "hint_statistics", aspectRatio: 1.206000000,
        targets: [:])
    static let studyFinished = Self(assetName: "hint_study_finished", aspectRatio: 0.813765182,
        targets: ["reward": CGRect(x: 0.085585751, y: 0.703253248, width: 0.828828498, height: 0.099777778)])
    static let timeSettings = Self(assetName: "hint_time_settings", aspectRatio: 0.797619048,
        targets: ["save": CGRect(x: 0.798569342, y: 0.196971492, width: 0.133759065, height: 0.068585643)])
    static let timerCountdown = Self(assetName: "hint_timer_countdown", aspectRatio: 0.820408163,
        targets: ["mode": CGRect(x: 0.079601990, y: 0.397959184, width: 0.840796020, height: 0.083673469), "settings": CGRect(x: 0.713930348, y: 0.658503401, width: 0.104477612, height: 0.085714286)])
    static let timerPaused = Self(assetName: "hint_timer_paused", aspectRatio: 0.820408163,
        targets: ["finish": CGRect(x: 0.350331662, y: 0.692857143, width: 0.300165850, height: 0.092516965), "resume": CGRect(x: 0.078358209, y: 0.553401340, width: 0.843283582, height: 0.104761926)])
    static let timerPomodoro = Self(assetName: "hint_timer_pomodoro", aspectRatio: 0.820408163,
        targets: ["category": CGRect(x: 0.079601990, y: 0.267346939, width: 0.194029851, height: 0.073469388), "mode": CGRect(x: 0.079601990, y: 0.357142857, width: 0.840796020, height: 0.083673469), "settings": CGRect(x: 0.713930348, y: 0.617687075, width: 0.104477612, height: 0.085714286), "start": CGRect(x: 0.078358209, y: 0.865646300, width: 0.843283582, height: 0.104761863)])
    static let timerRunning = Self(assetName: "hint_timer_running", aspectRatio: 0.820408163,
        targets: ["pause": CGRect(x: 0.078358209, y: 0.617346939, width: 0.843283582, height: 0.104081633)])
    static let timerStopwatch = Self(assetName: "hint_timer_stopwatch", aspectRatio: 0.820408163,
        targets: ["mode": CGRect(x: 0.079601990, y: 0.397959184, width: 0.840796020, height: 0.083673469)])
    static let trial = Self(assetName: "hint_trial", aspectRatio: 1.415492958,
        targets: ["nudge": CGRect(x: 0.296849088, y: 0.173708920, width: 0.189054726, height: 0.183098592)])
    static let trialClose = Self(assetName: "hint_trial_close", aspectRatio: 2.364705882,
        targets: ["close": CGRect(x: 0.741293532, y: 0.170588235, width: 0.179104478, height: 0.201960784)])
    static let stackingMenu = Self(assetName: "hint_decoration_stacking_menu", aspectRatio: 2.065068493,
        targets: ["menu": CGRect(x: 0.368159204, y: 0.143835616, width: 0.199004975, height: 0.267123288)])
    static let stackingControls = Self(assetName: "hint_decoration_stacking_controls", aspectRatio: 2.065068493,
        targets: ["controls": CGRect(x: 0.256218905, y: 0.143835616, width: 0.483416252, height: 0.267123288)])

    // 統計の新しい撮影分。カテゴリ別グラフは既存のstatistics画像を共有する。
    static let statisticsOverview = Self(assetName: "hint_statistics_overview", aspectRatio: 0.827160494,
        targets: ["period": CGRect(x: 0.074626866, y: 0.037037037, width: 0.850746269, height: 0.063786008)])
    static let statisticsSelection = Self(assetName: "hint_statistics_selection", aspectRatio: 0.827160494,
        targets: ["chart": CGRect(x: 0.074626866, y: 0.455418381, width: 0.850746269, height: 0.534979424), "detail": CGRect(x: 0.667495854, y: 0.342249657, width: 0.257877280, height: 0.070644719)])
    static let statisticsDetail = Self(assetName: "hint_statistics_detail", aspectRatio: 0.913636364,
        targets: [:])
    static let statisticsSessions = Self(assetName: "hint_statistics_sessions", aspectRatio: 1.675000000,
        targets: [:])
}
