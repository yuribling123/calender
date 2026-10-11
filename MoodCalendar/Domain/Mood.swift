import SwiftUI

enum Mood: Int, CaseIterable, Identifiable, Codable {
    case veryGood = 5, good = 4, okay = 3, bad = 2, veryBad = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .veryGood: localized("极好")
        case .good: localized("好")
        case .okay: localized("一般")
        case .bad: localized("不好")
        case .veryBad: localized("很差")
        }
    }

    var caption: String {
        switch self {
        case .veryGood: localized("幸福到融化")
        case .good: localized("心里软乎乎")
        case .okay: localized("今天就这样")
        case .bad: localized("小小不开心")
        case .veryBad: localized("快要碎掉了")
        }
    }

    var imageName: String {
        switch self {
        case .veryGood: "moodVeryGood"
        case .good: "moodGood"
        case .okay: "moodOkay"
        case .bad: "moodBad"
        case .veryBad: "moodVeryBad"
        }
    }

    var color: Color {
        switch self {
        case .veryGood: Color(red: 242/255, green: 141/255, blue: 178/255)
        case .good: Color(red: 243/255, green: 165/255, blue: 143/255)
        case .okay: Color(red: 232/255, green: 201/255, blue: 130/255)
        case .bad: Color(red: 145/255, green: 169/255, blue: 197/255)
        case .veryBad: Color(red: 169/255, green: 154/255, blue: 185/255)
        }
    }
}
