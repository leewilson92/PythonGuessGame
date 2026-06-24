import Foundation
import SwiftData

/// 房贷的三个动作：确认本月还款 / 提前还款 / 改利率。
/// 每个动作都会更新分部的实时状态，并写一条历史记录。
struct LoanService {
    let context: ModelContext

    /// 确认本月还款：按当前剩余本金、利率、剩余期数算出拆分，记一笔并减负债。
    @discardableResult
    func confirmMonthlyPayment(for tranche: LoanTranche, date: Date = .now) -> LoanPayment? {
        guard tranche.currentPrincipal > 0, tranche.remainingTerms > 0 else { return nil }
        let split = MortgageCalculator.nextSplit(
            principal: tranche.currentPrincipal,
            annualRate: tranche.annualRate,
            remainingTerms: tranche.remainingTerms
        )
        let payment = LoanPayment(
            date: date,
            totalAmount: split.total,
            principal: split.principal,
            interest: split.interest,
            tranche: tranche
        )
        context.insert(payment)

        tranche.currentPrincipal = max(0, tranche.currentPrincipal - split.principal)
        tranche.remainingTerms = max(0, tranche.remainingTerms - 1)
        return payment
    }

    /// 提前还款：减少剩余本金，保持期数不变 → 后续月供自动变小。
    func prepay(_ amount: Decimal, for tranche: LoanTranche, date: Date = .now) {
        guard amount > 0 else { return }
        let event = LoanEvent(date: date, type: .prepayment, amount: amount, tranche: tranche)
        context.insert(event)
        tranche.currentPrincipal = max(0, tranche.currentPrincipal - amount)
    }

    /// 改利率：更新年利率 → 后续月供按新利率重算。
    func changeRate(to newAnnualRate: Decimal, for tranche: LoanTranche, date: Date = .now) {
        let event = LoanEvent(date: date, type: .rateChange, newAnnualRate: newAnnualRate, tranche: tranche)
        context.insert(event)
        tranche.annualRate = newAnnualRate
    }
}
