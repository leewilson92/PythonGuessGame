import XCTest
@testable import ExpenseTracker

/// `BudgetStatus` 纯逻辑白盒测试（无 SwiftData / 无 UI）。
/// 覆盖设计第 6 节 A 组 B-1~B-7：已用 / 剩余 / 超支 / 文案 / 进度 / 边界 / Decimal 无浮点误差。
final class BudgetStatusTests: XCTestCase {

    // MARK: - B-1 预算 2000、已用 800 → 剩 1200、未超支、未到红线、文案「剩 ¥1,200.00」

    func testB1_UnderBudget() {
        let s = BudgetStatus(budget: 2000, used: 800)
        XCTAssertEqual(s.remaining, 1200)
        XCTAssertFalse(s.isOverspent)
        XCTAssertFalse(s.atOrOverLimit)
        XCTAssertEqual(s.overspentAmount, 0)
        XCTAssertEqual(s.statusText, "剩 \(Money.string(1200))")
    }

    // MARK: - B-2 预算 2000、已用 1100（800+300）→ 剩 900、未超支

    func testB2_UnderBudgetAfterMore() {
        let s = BudgetStatus(budget: 2000, used: 1100)
        XCTAssertEqual(s.remaining, 900)
        XCTAssertFalse(s.isOverspent)
        XCTAssertFalse(s.atOrOverLimit)
    }

    // MARK: - B-3 预算 2000、已用 2200 → 超支、超 200、到红线、文案「超支 ¥200.00」

    func testB3_Overspent() {
        let s = BudgetStatus(budget: 2000, used: 2200)
        XCTAssertTrue(s.isOverspent)
        XCTAssertEqual(s.overspentAmount, 200)
        XCTAssertTrue(s.atOrOverLimit)
        XCTAssertEqual(s.remaining, -200)
        XCTAssertEqual(s.statusText, "超支 \(Money.string(200))")
    }

    // MARK: - B-4 边界：已用 == 预算（2000/2000）→ 未超支但到红线、剩 ¥0.00

    func testB4_ExactlyAtLimit() {
        let s = BudgetStatus(budget: 2000, used: 2000)
        XCTAssertFalse(s.isOverspent)          // 严格 > 才算超支
        XCTAssertTrue(s.atOrOverLimit)         // 恰好用满即变红
        XCTAssertEqual(s.remaining, 0)
        XCTAssertEqual(s.overspentAmount, 0)
        XCTAssertEqual(s.statusText, "剩 \(Money.string(0))")
        XCTAssertEqual(s.fraction, 1.0, accuracy: 0.0001)
    }

    // MARK: - B-5 已用 0 → 剩余 = 预算、进度 0、未超支

    func testB5_ZeroUsed() {
        let s = BudgetStatus(budget: 2000, used: 0)
        XCTAssertEqual(s.remaining, 2000)
        XCTAssertEqual(s.fraction, 0.0, accuracy: 0.0001)
        XCTAssertFalse(s.isOverspent)
        XCTAssertFalse(s.atOrOverLimit)
        XCTAssertEqual(s.statusText, "剩 \(Money.string(2000))")
    }

    // MARK: - B-6 fraction 单调 / clamp / 防除零

    func testB6_FractionClampAndMonotonic() {
        XCTAssertEqual(BudgetStatus(budget: 2000, used: 0).fraction, 0.0, accuracy: 0.0001)
        XCTAssertEqual(BudgetStatus(budget: 2000, used: 1000).fraction, 0.5, accuracy: 0.0001)
        XCTAssertEqual(BudgetStatus(budget: 2000, used: 2000).fraction, 1.0, accuracy: 0.0001)
        // 已用 > 预算 → 夹到 1，不超过 1
        XCTAssertEqual(BudgetStatus(budget: 2000, used: 5000).fraction, 1.0, accuracy: 0.0001)
        // budget <= 0 → 0，不崩、不除零
        XCTAssertEqual(BudgetStatus(budget: 0, used: 100).fraction, 0.0, accuracy: 0.0001)
        XCTAssertEqual(BudgetStatus(budget: -10, used: 100).fraction, 0.0, accuracy: 0.0001)
    }

    // MARK: - B-7 Decimal 无浮点误差：预算 0.30、已用 0.10 → 剩 0.20

    func testB7_DecimalNoFloatError() {
        let s = BudgetStatus(budget: Decimal(string: "0.30")!, used: Decimal(string: "0.10")!)
        XCTAssertEqual(s.remaining, Decimal(string: "0.20")!)
        XCTAssertFalse(s.isOverspent)

        // 超支金额也是精确 Decimal
        let over = BudgetStatus(budget: Decimal(string: "0.10")!, used: Decimal(string: "0.30")!)
        XCTAssertEqual(over.overspentAmount, Decimal(string: "0.20")!)
        XCTAssertTrue(over.isOverspent)
    }
}
