import Foundation

/// 月度预算的纯逻辑层：由「预算金额 + 本月已用」派生出展示所需的一切。
///
/// 无 SwiftData / 无 UI 依赖，供 `BudgetCard` 渲染、供 XCTest 直接验证。
/// 金额属性（`remaining` / `overspentAmount`）一律 `Decimal`；唯一的 `Double`（`fraction`）
/// 只用于进度条长度（0…1），**绝不参与任何金额运算**。
struct BudgetStatus {
    /// 总预算（业务上 > 0；写入侧已用 `canSave` 拦住 ≤ 0，但 `fraction` 仍对 ≤ 0 防除零）。
    let budget: Decimal
    /// 本月已用（= `MonthlySummary.dailySpending`，≥ 0）。
    let used: Decimal

    init(budget: Decimal, used: Decimal) {
        self.budget = budget
        self.used = used
    }

    /// 剩余额度（可为负）。
    var remaining: Decimal { budget - used }

    /// 是否超支：严格「已用 > 预算」才算（恰好用满不算超支）。
    var isOverspent: Bool { used > budget }

    /// 超出金额：超支时为「已用 − 预算」，否则 0。
    var overspentAmount: Decimal { isOverspent ? used - budget : 0 }

    /// 是否到 / 超 100%（变红阈值）：恰好用满（`used == budget`）也变红。
    /// 注意与 `isOverspent`（严格 >）的区别：用满 100% 变红但「剩 ¥0.00」、未超支。
    var atOrOverLimit: Bool { used >= budget }

    /// 进度比例（0…1），仅用于进度条长度。超支夹到 1（条满）；`budget <= 0` 视为 0 防除零。
    /// `Decimal → Double` 仅用于 UI 条长度，不参与金额运算。
    var fraction: Double {
        guard budget > 0 else { return 0 }
        let ratio = (used as NSDecimalNumber).doubleValue / (budget as NSDecimalNumber).doubleValue
        if ratio < 0 { return 0 }
        if ratio > 1 { return 1 }
        return ratio
    }

    /// 卡片副标题文案：超支显示「超支 ¥X」，否则「剩 ¥X」（用满 100% 时为「剩 ¥0.00」）。
    var statusText: String {
        if isOverspent {
            return "超支 \(Money.string(overspentAmount))"
        } else {
            return "剩 \(Money.string(remaining))"
        }
    }
}
