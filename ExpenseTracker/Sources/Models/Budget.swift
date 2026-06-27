import Foundation
import SwiftData

/// 本月总预算。单一总预算、不按月留历史、不结转 —— 全库只存一行「当前预算金额」。
///
/// - 唯一字段 `monthlyAmount: Decimal`（守「金额一律 `Decimal`」）。
/// - 已用 / 剩余 / 超支 / 进度均为派生值，由 `BudgetStatus` 运行时计算，不落库。
/// - 「获取或创建」由 `BudgetEditView` 单一写入入口保证唯一（见设计 3.2）；读取侧取 `budgets.first`。
@Model
final class Budget {
    /// 本月总支出上限，> 0。
    var monthlyAmount: Decimal

    init(monthlyAmount: Decimal) {
        self.monthlyAmount = monthlyAmount
    }
}
