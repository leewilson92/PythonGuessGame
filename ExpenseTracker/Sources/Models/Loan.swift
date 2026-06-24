import Foundation
import SwiftData

/// 一套房贷（混合贷由多个 LoanTranche 组成，例如「公积金贷 + 商贷」）。
@Model
final class Loan {
    var name: String

    @Relationship(deleteRule: .cascade, inverse: \LoanTranche.loan)
    var tranches: [LoanTranche] = []

    init(name: String = "房贷") {
        self.name = name
    }

    /// 整套房贷当前负债总剩余。
    var totalRemaining: Decimal {
        tranches.reduce(0) { $0 + $1.currentPrincipal }
    }

    /// 已还本金合计。
    var totalPaidPrincipal: Decimal {
        tranches.reduce(0) { $0 + $1.paidPrincipal }
    }
}

/// 房贷的一部分（公积金贷 / 商贷），各自利率、期数。
///
/// 设计取舍（MVP）：采用「可变实时状态 + 历史流水」而非每次全量回放。
/// `currentPrincipal / annualRate / remainingTerms` 是实时状态，
/// 每次确认还款 / 提前还款 / 改利率时更新；`payments / events` 作为历史与审计。
/// 这样实现简单、稳定，足够个人单机使用。
@Model
final class LoanTranche {
    var name: String

    // 期初参考值（建档时填的，仅供展示/回看）
    var openingPrincipal: Decimal
    var originalTerms: Int

    // 实时状态（随操作变化）
    var currentPrincipal: Decimal
    var annualRate: Decimal      // 年利率，如 0.031 表示 3.1%
    var remainingTerms: Int

    var repaymentMethodRaw: String

    @Relationship(deleteRule: .nullify)
    var loan: Loan?

    @Relationship(deleteRule: .cascade, inverse: \LoanPayment.tranche)
    var payments: [LoanPayment] = []

    @Relationship(deleteRule: .cascade, inverse: \LoanEvent.tranche)
    var events: [LoanEvent] = []

    var repaymentMethod: RepaymentMethod {
        get { RepaymentMethod(rawValue: repaymentMethodRaw) ?? .equalInstallment }
        set { repaymentMethodRaw = newValue.rawValue }
    }

    /// 已还本金 = 期初 − 当前剩余。
    var paidPrincipal: Decimal {
        max(0, openingPrincipal - currentPrincipal)
    }

    init(name: String,
         openingPrincipal: Decimal,
         annualRate: Decimal,
         remainingTerms: Int,
         repaymentMethod: RepaymentMethod = .equalInstallment) {
        self.name = name
        self.openingPrincipal = openingPrincipal
        self.currentPrincipal = openingPrincipal
        self.originalTerms = remainingTerms
        self.remainingTerms = remainingTerms
        self.annualRate = annualRate
        self.repaymentMethodRaw = repaymentMethod.rawValue
    }
}

/// 每月还款记录（确认时按公式算好、定格存下）。
@Model
final class LoanPayment {
    var date: Date
    var totalAmount: Decimal
    var principal: Decimal
    var interest: Decimal

    @Relationship(deleteRule: .nullify)
    var tranche: LoanTranche?

    init(date: Date = .now,
         totalAmount: Decimal,
         principal: Decimal,
         interest: Decimal,
         tranche: LoanTranche? = nil) {
        self.date = date
        self.totalAmount = totalAmount
        self.principal = principal
        self.interest = interest
        self.tranche = tranche
    }
}

/// 影响计算的手动事件：提前还款 / 改利率。作为审计记录。
@Model
final class LoanEvent {
    var date: Date
    var typeRaw: String
    /// 提前还款金额（type == .prepayment）
    var amount: Decimal?
    /// 新年利率（type == .rateChange）
    var newAnnualRate: Decimal?

    @Relationship(deleteRule: .nullify)
    var tranche: LoanTranche?

    var type: LoanEventType {
        get { LoanEventType(rawValue: typeRaw) ?? .prepayment }
        set { typeRaw = newValue.rawValue }
    }

    init(date: Date = .now,
         type: LoanEventType,
         amount: Decimal? = nil,
         newAnnualRate: Decimal? = nil,
         tranche: LoanTranche? = nil) {
        self.date = date
        self.typeRaw = type.rawValue
        self.amount = amount
        self.newAnnualRate = newAnnualRate
        self.tranche = tranche
    }
}
