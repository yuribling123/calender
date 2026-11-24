import SwiftUI

struct MembershipScreen: View {
    @EnvironmentObject private var membership: MembershipStore
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 22) {
                        HStack(spacing: 12) {
                            ForEach([DailyChoice.clover, .guitar, .starRabbit, .wings], id: \.rawValue) { choice in
                                ChoiceArtwork(choice: choice)
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
                            benefit(localized("解锁所有表情包"), detail: localized(
                                "包括%@等全部表情包。", groupNames(memberOnly: true)
                            ))
                            benefit(localized("解锁所有月便签皮肤"), detail: localized(
                                "包括%@等皮肤。", noteSkinNames(memberOnly: true)
                            ))
                            benefit(localized("自定义日历"), detail: localized(
                                "解锁%@主题，以及%@选中图形。",
                                themeNames(memberOnly: true), shapeNames(memberOnly: true)
                            ))
                            benefit(localized("新表情皮肤，持续解锁"), detail: localized(
                                "后续上新的全部表情皮肤，也都包含在会员权益中，无需另行购买。"
                            ))
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.palette.resolved(for: colorScheme).cardBackground, in: RoundedRectangle(cornerRadius: 20))

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
                            .background(theme.palette.todayButtonFill, in: Capsule())
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
                    .iPadReadableWidth(520)
                }
            }
            .background(theme.palette.resolved(for: colorScheme).background.ignoresSafeArea())
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

    // Keep the benefit lists aligned with the same definitions used by the pickers.
    private func groupNames(memberOnly: Bool) -> String {
        ChoiceGroup.allCases.filter { $0.requiresMembership == memberOnly }
            .map(\.title).joined(separator: localized("、"))
    }

    private func themeNames(memberOnly: Bool) -> String {
        AppTheme.allCases.filter { $0.requiresMembership == memberOnly }
            .map(\.title).joined(separator: localized("、"))
    }

    private func shapeNames(memberOnly: Bool) -> String {
        SelectionShape.allCases.filter { $0.requiresMembership == memberOnly }
            .map(\.title).joined(separator: localized("、"))
    }

    private func noteSkinNames(memberOnly: Bool) -> String {
        MonthlyNoteSkin.selectableSkins.filter { $0.requiresMembership == memberOnly }
            .map { localized($0.title) }.joined(separator: localized("、"))
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
