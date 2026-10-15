import Foundation

enum AppLanguage {
    static let options = ["zh-Hans", "en", "ja", "ko"]
    static func initialLanguage(for systemLanguage: String) -> String {
        switch systemLanguage.split(separator: "-").first {
        case "zh": "zh-Hans"
        case "ja": "ja"
        case "ko": "ko"
        default: "en"
        }
    }
    static var selection: String {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"), options.contains(saved) {
            return saved
        }
        return initialLanguage(for: Locale.preferredLanguages.first ?? "en")
    }
    static func prepareSelection() {
        // Also replaces the former "system" option with a supported language.
        UserDefaults.standard.set(selection, forKey: "appLanguage")
    }
    static var locale: Locale { Locale(identifier: selection) }
    static func name(_ code: String) -> String {
        switch code {
        case "zh-Hans": "简体中文"
        case "en": "English"
        case "ja": "日本語"
        case "ko": "한국어"
        default: "English"
        }
    }
}

/// Formats translated UI text while keeping saved IDs and user-written notes stable.
func localized(_ key: String, _ arguments: CVarArg...) -> String {
    let bundle: Bundle
    if let path = Bundle.main.path(forResource: AppLanguage.selection, ofType: "lproj"),
       let languageBundle = Bundle(path: path) {
        bundle = languageBundle
    } else {
        bundle = .main
    }
    let format = bundle.localizedString(forKey: key, value: nil, table: nil)
    return arguments.isEmpty ? format : String(format: format, locale: AppLanguage.locale, arguments: arguments)
}

enum ChoiceGroup: String, CaseIterable, Identifiable {
    case mood = "心情"
    case activity = "日常"
    case company = "陪伴"
    case daily = "小幸"
    case playful = "随性"
    case rabbit = "兔兔"

    var id: String { rawValue }
    var title: String { localized(rawValue) }
}

/// Saved IDs 1–5 belong to the original moods and must stay unchanged.
enum DailyChoice: Int, CaseIterable, Identifiable {
    case veryBad = 1, bad = 2, okay = 3, good = 4, veryGood = 5
    case clover = 6, heart = 7, music = 8, coffee = 9, cake = 10
    case exercise = 11, work = 12, relax = 13, gather = 14, study = 15
    case family = 16, thinkingOfSomeone = 17, fluffy = 18, alone = 19, friends = 20
    case guitar = 21, wings = 22, cocktail = 23
    case lighter = 24, quill = 25
    case starRabbit = 26, glassesRabbit = 27, tearfulRabbit = 28, poutyRabbit = 29, absentRabbit = 30

    var id: Int { rawValue }
    var mood: Mood? { Mood(rawValue: rawValue) }
    var group: ChoiceGroup {
        if mood != nil { return .mood }
        if rawValue <= 10 { return .daily }
        if rawValue <= 15 { return .activity }
        if rawValue <= 20 { return .company }
        return rawValue <= 25 ? .playful : .rabbit
    }

    static func choices(in group: ChoiceGroup) -> [DailyChoice] {
        switch group {
        case .mood: [.veryGood, .good, .okay, .bad, .veryBad]
        case .daily: [.clover, .heart, .music, .coffee, .cake]
        case .activity: [.exercise, .work, .relax, .gather, .study]
        case .company: [.alone, .thinkingOfSomeone, .fluffy, .friends, .family]
        case .playful: [.guitar, .wings, .cocktail, .lighter, .quill]
        case .rabbit: [.starRabbit, .glassesRabbit, .tearfulRabbit, .poutyRabbit, .absentRabbit]
        }
    }

    var title: String {
        if let mood { return mood.title }
        return switch self {
        case .clover: localized("幸运草")
        case .heart: localized("爱心")
        case .music: localized("听歌")
        case .coffee: localized("咖啡")
        case .cake: localized("小蛋糕")
        case .exercise: localized("运动")
        case .work: localized("工作")
        case .relax: localized("放松")
        case .gather: localized("聚一聚")
        case .study: localized("学习")
        case .family: localized("和家人")
        case .thinkingOfSomeone: localized("想一个人")
        case .fluffy: localized("毛绒绒")
        case .alone: localized("独处")
        case .friends: localized("和朋友")
        case .guitar: localized("电吉他")
        case .wings: localized("翅膀")
        case .cocktail: localized("鸡尾酒")
        case .lighter: localized("打火机")
        case .quill: localized("羽毛笔")
        case .starRabbit: localized("星星兔")
        case .glassesRabbit: localized("眼镜兔")
        case .tearfulRabbit: localized("委屈兔")
        case .poutyRabbit: localized("笑晕兔")
        case .absentRabbit: localized("无语兔")
        default: ""
        }
    }

    var caption: String {
        if let mood { return mood.caption }
        return switch self {
        case .clover: localized("被世界偏爱了一点")
        case .heart: localized("一眼沦陷")
        case .music: localized("世界退到耳机外面")
        case .coffee: localized("找个角落坐坐")
        case .cake: localized("吃到了好吃的")
        case .exercise: localized("动一动，状态回来啦")
        case .work: localized("认真忙了一会")
        case .relax: localized("什么都不做也很好")
        case .gather: localized("出来碰个头")
        case .study: localized("知识进度加一")
        case .family: localized("和家人窝在一起")
        case .thinkingOfSomeone: localized("脑袋里偷偷住进一个人")
        case .fluffy: localized("被毛茸茸治愈了一下")
        case .alone: localized("把时间留给自己")
        case .friends: localized("见想见的人")
        case .guitar: localized("指尖藏着旋律")
        case .wings: localized("现实世界稍后再说")
        case .cocktail: localized("今晚不接受无聊邀请")
        case .lighter: localized("随心所欲的漂亮")
        case .quill: localized("把奇思妙想变成真的")
        case .starRabbit: localized("今天的可爱额度超标了")
        case .glassesRabbit: localized("看起来很懂，其实不太懂")
        case .tearfulRabbit: localized("没哭，只是眼睛下雨了")
        case .poutyRabbit: localized("哈哈哈哈救命啊")
        case .absentRabbit: localized("这都什么跟什么啊")
        default: ""
        }
    }

    var imageName: String {
        if let mood { return mood.imageName }
        return switch self {
        case .clover: "dailyClover"
        case .heart: "dailyHeart"
        case .music: "dailyMusic"
        case .coffee: "dailyCoffee"
        case .cake: "dailyCake"
        case .exercise: "activityExercise"
        case .work: "activityWork"
        case .relax: "activityRelax"
        case .gather: "activityGather"
        case .study: "activityStudy"
        case .family: "companyFamily"
        case .thinkingOfSomeone: "companyThinking"
        case .fluffy: "companyFluffy"
        case .alone: "companyAlone"
        case .friends: "companyFriends"
        case .guitar: "playfulGuitar"
        case .wings: "playfulWings"
        case .cocktail: "playfulCocktail"
        case .lighter: "playfulLighter"
        case .quill: "playfulQuill"
        case .starRabbit: "rabbitStar"
        case .glassesRabbit: "rabbitGlasses"
        case .tearfulRabbit: "rabbitTears"
        case .poutyRabbit: "rabbitPout"
        case .absentRabbit: "rabbitAbsent"
        default: ""
        }
    }

}
