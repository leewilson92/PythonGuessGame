import Foundation

/// 某个自然月的财务汇总。两种口径并存：
/// - 支出（消耗口径）= 日常消费实付 + 房贷利息
/// - 现金流出（现金口径）= 日常消费实付 + 房贷全额还款
///
/// 信用卡消费在刷卡当时已记为支出；“还信用卡”不进这里，避免重复计。
struct MonthlySummary {
    let month: Date

    /// 日常消费实付合计（仅支出类交易）。
    var dailySpending: Decimal = 0
    /// 本月房贷利息合计。
    var loanInterest: Decimal = 0
    /// 本月房贷还款总额合计（本金 + 利息）。
    var loanTotalPaid: Decimal = 0
    /// 本月优惠合计（省了多少）。
    var discountTotal: Decimal = 0
    /// 哪张卡省得最多。
    var topSavingMethodName: String?
    var topSavingAmount: Decimal = 0

    /// 支出（消耗口径）= 消费实付 + 房贷利息。
    var expenseView: Decimal { dailySpending + loanInterest }

    /// 现金流出（现金口径）= 消费实付 + 房贷全额还款。
    var cashOutflowView: Decimal { dailySpending + loanTotalPaid }

    /// 从交易与房贷还款计算某月汇总。
    static func make(month: Date,
                     transactions: [Transaction],
                     loanPayments: [LoanPayment],
                     calendar: Calendar = .current) -> MonthlySummary {
        var summary = MonthlySummary(month: month)

        let monthlyTx = transactions.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
        let expenseTx = monthlyTx.filter { $0.kind == .expense }

        summary.dailySpending = expenseTx.reduce(0) { $0 + $1.actualAmount }
        summary.discountTotal = expenseTx.reduce(0) { $0 + $1.discount }

        // 按支付方式累计优惠，取最高。
        var savingByMethod: [String: Decimal] = [:]
        for tx in expenseTx where tx.discount > 0 {
            let key = tx.paymentMethod?.name ?? "未指定"
            savingByMethod[key, default: 0] += tx.discount
        }
        if let top = savingByMethod.max(by: { $0.value < $1.value }), top.value > 0 {
            summary.topSavingMethodName = top.key
            summary.topSavingAmount = top.value
        }

        let monthlyPayments = loanPayments.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
        summary.loanInterest = monthlyPayments.reduce(0) { $0 + $1.interest }
        summary.loanTotalPaid = monthlyPayments.reduce(0) { $0 + $1.totalAmount }

        return summary
    }
}
