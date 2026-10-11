import Foundation
import SwiftData

/// Launch with -demoData in Debug to use disposable examples instead of the user's store.
enum DemoData {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-demoData")
        #else
        false
        #endif
    }

    #if DEBUG
    @MainActor
    static func seed(into context: ModelContext) throws {
        let year = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())

        // The demo store is in-memory and recreated at every launch. Seed each
        // example independently so a partial/early fetch cannot leave it blank.
        let seededMonthKeys = Set(try context.fetch(FetchDescriptor<MonthlyNote>()).map(\.monthKey))
        if !seededMonthKeys.contains("\(year)-08") {
            context.insert(MonthlyNote(monthKey: "\(year)-08", text: localized("慢一点 也没关系")))
        }
        if !seededMonthKeys.contains("\(year)-09") {
            context.insert(MonthlyNote(monthKey: "\(year)-09", text: localized("我发现人只要一出门，就很容易花钱。买杯喝的、顺手吃点东西，最后拎着一堆东西回家并思考自己刚刚经历了什么")))
        }
        if !seededMonthKeys.contains("2022-02") {
            context.insert(MonthlyNote(monthKey: "2022-02", text: localized("很久以前的一个月，也值得好好记住。")))
        }
        let currentMonthKey = String(format: "%04d-%02d", year, currentMonth)
        if !seededMonthKeys.contains(currentMonthKey) {
            context.insert(MonthlyNote(
                monthKey: currentMonthKey,
                text: localized("这个月，见了想见的人，也有认真听完的一首歌。\n把日子慢慢过好，平常的小事也值得记下来。")
            ))
        }

        let existingDayKeys = Set(try context.fetch(FetchDescriptor<MoodEntry>()).map(\.dayKey))
        let examples: [(Int, Int, DailyChoice, String)] = [
            // June: 5 records, covering all three choice groups.
            (6, 3, .good, localized("天气很好，心里亮了一点。")),
            (6, 9, .bad, ""),
            (6, 15, .coffee, ""),
            (6, 21, .exercise, localized("动一动，状态回来啦。")),
            (6, 27, .study, ""),
            // August: 6 records, covering all three choice groups.
            (8, 2, .veryGood, ""),
            (8, 8, .okay, ""),
            (8, 14, .music, ""),
            (8, 19, .cake, localized("吃到了喜欢的甜点。")),
            (8, 24, .work, ""),
            (8, 29, .relax, ""),
            // September: all 30 choices, one per day across the six groups.
            (9, 1, .good, localized("咖啡店给我的杯子上画了一个歪歪的小爱心。虽然可能人人都有，但我决定当作只画给我的")),
            (9, 4, .veryGood, ""),
            (9, 7, .bad, localized("事情有点多，先允许自己慢下来。")),
            (9, 10, .clover, ""),
            (9, 13, .heart, localized("见到喜欢的人，心情亮了一下。")),
            (9, 16, .coffee, ""),
            (9, 19, .exercise, localized("动一动之后，状态真的回来了。")),
            (9, 22, .work, ""),
            (9, 25, .study, localized("终于把一直没弄懂的地方想明白了。")),
            (9, 28, .gather, ""),
            (9, 2, .fluffy, localized("抱着毛绒绒发了会儿呆，软软的触感让忙乱的心也安静下来。")),
            (9, 30, .music, localized("晚上戴上耳机听歌，熟悉的旋律一首接一首，把白天没来得及整理的情绪慢慢安放好。窗外渐渐安静下来，我也终于觉得今天可以结束了。")),
            (9, 9, .thinkingOfSomeone, localized("今天忽然很想一个人。看到熟悉的东西时，脑海里就浮现出和他一起度过的片段。虽然没能见面，还是希望他一切都好，也期待下次再见。")),
            (9, 12, .cake, localized("路过一家小店时，看到柜台里摆着一块看起来就很好吃的蛋糕。犹豫了一下还是买了下来，坐在窗边慢慢吃完。奶油不太甜，阳光刚好落在桌角，普通的一天也因为这点小小的满足变得可爱了。")),
            (9, 3, .okay, localized("平平常常，也有一点值得记住。")),
            (9, 5, .veryBad, localized("今天先好好休息。")),
            (9, 6, .relax, localized("把时间放慢一点。")),
            (9, 8, .family, localized("和家人一起吃了顿饭。")),
            (9, 11, .alone, localized("留一点时间给自己。")),
            (9, 14, .friends, localized("和朋友聊了好多。")),
            (9, 15, .guitar, localized("听到了一段喜欢的吉他旋律。")),
            (9, 17, .wings, localized("想象自己轻轻飞起来。")),
            (9, 18, .cocktail, localized("今晚碰个杯。")),
            (9, 20, .lighter, localized("留下一点小小的火光。")),
            (9, 21, .quill, localized("把想说的话写下来。")),
            (9, 23, .starRabbit, localized("今天眼里有星星。")),
            (9, 24, .glassesRabbit, localized("认真看世界的一天。")),
            (9, 26, .tearfulRabbit, localized("有一点委屈，抱抱自己。")),
            (9, 27, .poutyRabbit, localized("笑得停不下来。")),
            (9, 29, .absentRabbit, localized("暂时放空一下。"))
        ]

        let today = Calendar.current.startOfDay(for: Date())
        let currentDay = Calendar.current.component(.day, from: today)
        var launchExamples = examples
        let hasVisibleCurrentMonthExample = examples.contains {
            $0.0 == currentMonth && $0.1 <= currentDay
        }
        if !hasVisibleCurrentMonthExample {
            if currentDay > 1 {
                launchExamples.append((currentMonth, 1, .good, localized("给这个月留下一条演示记录。")))
            }
            launchExamples.append((currentMonth, currentDay, .veryGood, localized("今天的演示心情。")))
        }

        for (month, day, choice, note) in launchExamples {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = Calendar.current.date(from: components) else { continue }
            let dayKey = DayKey(date).storageValue
            guard !existingDayKeys.contains(dayKey) else { continue }
            context.insert(MoodEntry(dayKey: dayKey, choice: choice, note: note))
        }
        if !existingDayKeys.contains("2022-02-14") {
            context.insert(MoodEntry(dayKey: "2022-02-14", choice: .heart,
                                     note: localized("翻到 2022 年，看看月便签里还能不能找到这个月。")))
        }
        try context.save()
    }
    #endif
}
