import Foundation
import Combine
import StoreKit

@MainActor
final class MembershipStore: ObservableObject {
    static let productID = "com.qingqing.MoodCalendar.permanentUnlock"

    @Published private(set) var isUnlocked = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?

    var hasMembershipAccess: Bool { isUnlocked || DemoData.isEnabled }

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.apply(result)
            }
        }
        Task {
            await refreshEntitlements()
            await loadProduct()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProduct() async {
        guard !DemoData.isEnabled else { return }
        do {
            product = try await Product.products(for: [Self.productID]).first
            if product == nil {
                message = "暂时无法加载购买项目，请稍后重试。"
            }
        } catch {
            message = "暂时无法连接 App Store，请检查网络后重试。"
        }
    }

    func purchase() async {
        guard !isLoading, let product else { return }
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if isUnlocked { message = "已永久解锁全部表情包和自定义功能。" }
            case .pending:
                message = "购买正在等待批准。"
            case .userCancelled:
                break
            @unknown default:
                message = "购买未完成，请稍后重试。"
            }
        } catch {
            message = "购买未完成，请稍后重试。"
        }
    }

    func restorePurchases() async {
        guard !isLoading else { return }
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = isUnlocked ? "已恢复永久解锁。" : "当前 Apple 账户没有可恢复的购买。"
        } catch {
            message = "恢复购买失败，请稍后重试。"
        }
    }

    private func refreshEntitlements() async {
        guard !DemoData.isEnabled else { return }
        var hasUnlock = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil else { continue }
            hasUnlock = true
        }
        isUnlocked = hasUnlock
        enforceFreeCustomizationLimits()
    }

    private func apply(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result,
              transaction.productID == Self.productID else { return }
        await transaction.finish()
        // A transaction update can also report a refund or revocation. Re-read
        // the current entitlement instead of assuming every update grants access.
        await refreshEntitlements()
    }

    private func enforceFreeCustomizationLimits() {
        guard !isUnlocked, !DemoData.isEnabled else { return }
        let defaults = UserDefaults.standard
        let freeThemes: Set<String> = [AppTheme.pink.rawValue, AppTheme.black.rawValue]
        if !freeThemes.contains(defaults.string(forKey: "appTheme") ?? "") {
            defaults.set(AppTheme.pink.rawValue, forKey: "appTheme")
        }
        let freeShapes = [SelectionShape.circle.rawValue, SelectionShape.star.rawValue]
        if !freeShapes.contains(defaults.string(forKey: "selectionShape") ?? "") {
            defaults.set(SelectionShape.circle.rawValue, forKey: "selectionShape")
        }
    }
}
