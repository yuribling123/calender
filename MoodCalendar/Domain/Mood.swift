import SwiftUI

enum Mood: Int, CaseIterable, Identifiable, Codable {
    case veryGood = 5, good = 4, okay = 3, bad = 2, veryBad = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .veryGood: "极好"
        case .good: "好"
        case .okay: "一般"
        case .bad: "不好"
        case .veryBad: "很差"
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
