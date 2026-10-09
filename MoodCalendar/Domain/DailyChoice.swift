import Foundation

enum ChoiceGroup: String, CaseIterable, Identifiable {
    case mood = "心情"
    case activity = "做点事"
    case company = "陪伴"
    case daily = "日常"
    case playful = "心思"
    case rabbit = "兔兔"

    var id: String { rawValue }
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
        case .clover: "幸运草"
        case .heart: "爱心"
        case .music: "听歌"
        case .coffee: "咖啡"
        case .cake: "小蛋糕"
        case .exercise: "运动"
        case .work: "工作"
        case .relax: "放松"
        case .gather: "聚一聚"
        case .study: "学习"
        case .family: "和家人"
        case .thinkingOfSomeone: "想起一个人"
        case .fluffy: "毛绒绒"
        case .alone: "独处"
        case .friends: "和朋友"
        case .guitar: "电吉他"
        case .wings: "翅膀"
        case .cocktail: "鸡尾酒"
        case .lighter: "打火机"
        case .quill: "羽毛笔"
        case .starRabbit: "星星兔"
        case .glassesRabbit: "眼镜兔"
        case .tearfulRabbit: "委屈兔"
        case .poutyRabbit: "笑晕兔"
        case .absentRabbit: "无语兔"
        default: ""
        }
    }

    var caption: String {
        if let mood { return mood.caption }
        return switch self {
        case .clover: "被世界偏爱了一点"
        case .heart: "一眼沦陷"
        case .music: "世界退到耳机外面"
        case .coffee: "找个角落坐坐"
        case .cake: "吃到了好吃的"
        case .exercise: "动一动，状态回来啦"
        case .work: "认真忙了一会"
        case .relax: "什么都不做也很好"
        case .gather: "出来碰个头"
        case .study: "知识进度加一"
        case .family: "和家人窝在一起"
        case .thinkingOfSomeone: "脑袋里偷偷住进一个人"
        case .fluffy: "被毛茸茸治愈了一下"
        case .alone: "把时间留给自己"
        case .friends: "见想见的人"
        case .guitar: "指尖藏着旋律"
        case .wings: "现实世界稍后再说"
        case .cocktail: "今晚不接受无聊邀请"
        case .lighter: "随心所欲地漂亮"
        case .quill: "把奇思妙想变成真的"
        case .starRabbit: "今天的可爱额度超标了"
        case .glassesRabbit: "看起来很懂，其实不太懂"
        case .tearfulRabbit: "没哭，只是眼睛下雨了"
        case .poutyRabbit: "哈哈哈哈救命啊"
        case .absentRabbit: "这都什么跟什么啊"
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
