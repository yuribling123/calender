import SwiftUI

struct DayCell: View {
    let date: Date
    let mood: Mood?
    let isSelected: Bool
    let isFuture: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .opacity(isFuture ? 0.55 : 1)
                    .frame(width: 30, height: 30)
                    .background {
                        if isSelected {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(Mood.veryGood.color.opacity(0.35))
                        }
                    }

                Group {
                    if let mood {
                        Image(mood.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: min(50, geometry.size.width), height: min(50, geometry.size.width))
                            .clipped()
                            .blendMode(.multiply)
                            .accessibilityHidden(true)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 50)
            }
            .padding(.top, 3)
            .frame(width: geometry.size.width, height: 90, alignment: .top)
        }
        .frame(height: 90)
    }
}
