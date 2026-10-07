import Foundation

enum ChoiceGroup: String, CaseIterable, Identifiable {
    case mood = "心情"
    case daily = "小日常"
    case activity = "做点事"
    case company = "陪伴"

    var id: String { rawValue }
}

/// Saved IDs 1–5 belong to the original moods and must stay unchanged.
enum DailyChoice: Int, CaseIterable, Identifiable {
    case veryBad = 1, bad = 2, okay = 3, good = 4, veryGood = 5
    case clover = 6, heart = 7, music = 8, coffee = 9, cake = 10
    case exercise = 11, work = 12, relax = 13, gather = 14, study = 15
    case family = 16, thinkingOfSomeone = 17, fluffy = 18, alone = 19, friends = 20

    var id: Int { rawValue }
    var mood: Mood? { Mood(rawValue: rawValue) }
    var group: ChoiceGroup {
        if mood != nil { return .mood }
        if rawValue <= 10 { return .daily }
        return rawValue <= 15 ? .activity : .company
    }

    static func choices(in group: ChoiceGroup) -> [DailyChoice] {
        switch group {
        case .mood: [.veryGood, .good, .okay, .bad, .veryBad]
        case .daily: [.clover, .heart, .music, .coffee, .cake]
        case .activity: [.exercise, .work, .relax, .gather, .study]
        case .company: [.alone, .thinkingOfSomeone, .fluffy, .friends, .family]
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
        default: ""
        }
    }

    var caption: String {
        if let mood { return mood.caption }
        return switch self {
        case .clover: "被世界偏爱了一点"
        case .heart: "怦然心动"
        case .music: "世界退到耳机外面"
        case .coffee: "找个角落坐坐"
        case .cake: "吃到了好吃的"
        case .exercise: "动一动，状态回来啦"
        case .work: "认真忙了一会"
        case .relax: "什么都不做也很好"
        case .gather: "和喜欢的人见个面"
        case .study: "又懂了一点"
        case .family: "和家人窝在一起"
        case .thinkingOfSomeone: "脑袋里偷偷住进一个人"
        case .fluffy: "被毛茸茸治愈了一下"
        case .alone: "把时间留给自己"
        case .friends: "见到了想见的人"
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
        default: ""
        }
    }

}
