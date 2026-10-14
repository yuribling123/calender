import SwiftUI

struct MembershipScreen: View {
    @EnvironmentObject private var membership: MembershipStore
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 22) {
                        HStack(spacing: 12) {
                            ForEach([DailyChoice.clover, .guitar, .starRabbit, .wings], id: \.rawValue) { choice in
                                Image(choice.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 54, height: 44)
                                    .scaleEffect(1.35)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 22)
                        .padding(.bottom, 8)
                        .accessibilityHidden(true)

                        VStack(spacing: 8) {
                            Text(membership.hasMembershipAccess ? localized("已永久解锁") : localized("永久解锁今日份"))
                                .font(.title2.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(localized("一次购买，永久使用，无需订阅"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 24) {
                            benefit(localized("解锁全部表情包"), detail: localized("让兔兔、四叶草和小翅膀，陪你记下每一天。"))
                            benefit(localized("日历也有你的风格"), detail: localized("起个喜欢的名字，换上喜欢的颜色，让星星、花瓣或猫猫圈住今天。"))
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 20))

                        Spacer(minLength: 24)

                        VStack(spacing: 10) {
                            if let message = membership.message {
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            #if !DEBUG
                            if membership.productLoadFailed && !membership.hasMembershipAccess {
                                Button(localized("重试")) {
                                    Task { await membership.loadProduct() }
                                }
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(theme.palette.strongAccent)
                                .disabled(membership.isLoading)
                            }
                            #endif
                        }

                        Button {
                            Task { await membership.purchase() }
                        } label: {
                            HStack {
                                if membership.isLoading { ProgressView().tint(.white) }
                                Text(membership.hasMembershipAccess ? localized("已永久解锁") : purchaseTitle)
                                    .font(.body.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(theme.palette.strongAccent, in: Capsule())
                        }
                        .disabled(membership.hasMembershipAccess || membership.product == nil || membership.isLoading)

                        if !membership.hasMembershipAccess {
                            Button(localized("恢复购买")) {
                                Task { await membership.restorePurchases() }
                            }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(theme.palette.strongAccent)
                            .disabled(membership.isLoading || DemoData.isEnabled)
                        }

                        if DemoData.isEnabled {
                            Text(localized("演示模式不支持 App Store 购买"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(24)
                    .frame(minHeight: proxy.size.height)
                }
            }
            .background(theme.palette.background.ignoresSafeArea())
            .navigationTitle(localized("永久解锁"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("完成")) { dismiss() }
                }
            }
            .task { await membership.loadProduct() }
        }
    }

    private var purchaseTitle: String {
        if membership.hasMembershipAccess { return localized("已永久解锁") }
        if let price = membership.product?.displayPrice { return localized("永久解锁 · %@", String(describing: price)) }
        return membership.isLoading ? localized("正在连接 App Store…") : localized("永久解锁")
    }

    private func benefit(_ title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.palette.accent)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
