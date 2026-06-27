import XCTest
@testable import ExpenseTracker

final class MortgageCalculatorTests: XCTestCase {

    private func d(_ v: Decimal) -> Double { NSDecimalNumber(decimal: v).doubleValue }

    func testZeroRateIsPrincipalOverTerms() {
        let m = MortgageCalculator.monthlyPayment(principal: 12000, annualRate: 0, remainingTerms: 12)
        XCTAssertEqual(d(m), 1000, accuracy: 0.01)
    }

    func testKnownEqualInstallment() {
        // 100 万、年利率 4.9%、360 期，标准等额本息月供约 5307 元。
        let m = MortgageCalculator.monthlyPayment(principal: 1_000_000, annualRate: 0.049, remainingTerms: 360)
        XCTAssertEqual(d(m), 5307, accuracy: 5)
    }

    func testSplitSumsToTotal() {
        let split = MortgageCalculator.nextSplit(principal: 500_000, annualRate: 0.031, remainingTerms: 240)
        XCTAssertEqual(d(split.principal) + d(split.interest), d(split.total), accuracy: 0.02)
    }

    func testInterestIsPrincipalTimesMonthlyRate() {
        let principal: Decimal = 300_000
        let annual: Decimal = 0.036
        let split = MortgageCalculator.nextSplit(principal: principal, annualRate: annual, remainingTerms: 180)
        let expectedInterest = d(principal) * (0.036 / 12)
        XCTAssertEqual(d(split.interest), expectedInterest, accuracy: 0.02)
    }

    func testLastTermClearsPrincipal() {
        let principal: Decimal = 10_000
        let split = MortgageCalculator.nextSplit(principal: principal, annualRate: 0.05, remainingTerms: 1)
        XCTAssertEqual(d(split.principal), d(principal), accuracy: 0.01)
    }
}
