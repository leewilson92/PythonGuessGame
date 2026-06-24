import Foundation

/// 房贷计算（纯函数，便于单元测试）。
///
/// 等额本息月供公式：M = P·r·(1+r)^n / ((1+r)^n − 1)
/// 其中 r = 年利率 / 12，n = 剩余期数。
/// 当月利息 = 当前剩余本金 · r；当月本金 = 月供 − 利息。
///
/// Decimal 没有内置 pow，这里用 Double 做幂运算后回到 Decimal 并四舍五入到分，
/// 对个人记账精度足够。
enum MortgageCalculator {

    /// 等额本息月供。principal/n 非法时返回 0。
    static func monthlyPayment(principal: Decimal, annualRate: Decimal, remainingTerms n: Int) -> Decimal {
        guard principal > 0, n > 0 else { return 0 }
        let r = (annualRate / 12) as Decimal
        if r == 0 {
            return round2(principal / Decimal(n))
        }
        let rd = NSDecimalNumber(decimal: r).doubleValue
        let pd = NSDecimalNumber(decimal: principal).doubleValue
        let pow = Foundation.pow(1 + rd, Double(n))
        let payment = pd * rd * pow / (pow - 1)
        return round2(Decimal(payment))
    }

    /// 计算「下一期」的还款拆分：总额 / 本金 / 利息。
    static func nextSplit(principal: Decimal, annualRate: Decimal, remainingTerms n: Int) -> (total: Decimal, principal: Decimal, interest: Decimal) {
        guard principal > 0, n > 0 else { return (0, 0, 0) }
        let r = (annualRate / 12) as Decimal
        let payment = monthlyPayment(principal: principal, annualRate: annualRate, remainingTerms: n)
        let interest = round2(principal * r)
        // 最后一期：把剩余本金一次性还清，避免几分钱尾差。
        if n == 1 {
            let total = round2(principal + interest)
            return (total, principal, interest)
        }
        var principalPart = round2(payment - interest)
        if principalPart > principal { principalPart = principal }
        return (payment, principalPart, interest)
    }

    /// 四舍五入到分（2 位小数，银行家舍入用 .plain 即四舍五入）。
    static func round2(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }
}
