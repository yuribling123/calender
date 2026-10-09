import SwiftUI

struct MembershipScreen: View {
    @EnvironmentObject private var membership: MembershipStore
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: membership.hasMembershipAccess ? "checkmark.seal.fill" : "heart.text.square.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(theme.palette.accent)
                    .padding(.top, 22)

                VStack(spacing: 8) {
                    Text(membership.hasMembershipAccess ? "已永久解锁" : "解锁今日份完整体验")
                        .font(.title2.weight(.semibold))
                    Text("一次购买，永久使用")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    benefit("表情包", detail: "解锁全部表情包")
                    benefit("个性化设置", detail: "自定义日历标题，解锁全部主题色和选中图形")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 20))

                if let message = membership.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 0)

                Button {
                    Task { await membership.purchase() }
                } label: {
                    HStack {
                        if membership.isLoading { ProgressView().tint(.white) }
                        Text(membership.hasMembershipAccess ? "已永久解锁" : purchaseTitle)
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(theme.palette.strongAccent, in: Capsule())
                }
                .disabled(membership.hasMembershipAccess || membership.product == nil || membership.isLoading)

                if !membership.hasMembershipAccess {
                    Button("恢复购买") {
                        Task { await membership.restorePurchases() }
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(theme.palette.strongAccent)
                    .disabled(membership.isLoading || DemoData.isEnabled)
                }

                if DemoData.isEnabled {
                    Text("演示模式不支持 App Store 购买")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .background(theme.palette.background.ignoresSafeArea())
            .navigationTitle("永久解锁")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task { await membership.loadProduct() }
        }
    }

    private var purchaseTitle: String {
        if membership.hasMembershipAccess { return "已永久解锁" }
        if let price = membership.product?.displayPrice { return "永久解锁 · \(price)" }
        return membership.isLoading ? "正在连接 App Store…" : "永久解锁 · ¥12"
    }

    private func benefit(_ title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.palette.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
