import XCTest
import SwiftData
@testable import ExpenseTracker

// 消歧：`Category` 与 objc/runtime.h 的 `Category` 同名，显式指向本模型。
private typealias Category = ExpenseTracker.Category

/// 交易编辑「保存写回」与不变量的白盒测试。
/// 驱动 `TransactionForm`（纯逻辑层）+ `MonthlySummary`，不依赖 UI。
final class TransactionEditTests: XCTestCase {

    private var context: ModelContext!

    override func setUpWithError() throws {
        context = try TestContext.make()
    }

    override func tearDown() {
        context = nil
    }

    // MARK: - 帮助器

    /// 当月某一天，避免跨月边界。
    private func dayInThisMonth(_ day: Int = 15) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: .now)
        comps.day = day
        return cal.date(from: comps) ?? .now
    }

    private func summary(_ month: Date) -> MonthlySummary {
        let tx = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let pays = (try? context.fetch(FetchDescriptor<LoanPayment>())) ?? []
        return MonthlySummary.make(month: month, transactions: tx, loanPayments: pays)
    }

    // MARK: - T-3 改实付金额写回 + 汇总更新

    func testT3_EditActualAmountWriteBackAndSummary() throws {
        let date = dayInThisMonth()
        let tx = Transaction(date: date, actualAmount: 100, kind: .expense)
        context.insert(tx)

        XCTAssertEqual(summary(date).dailySpending, 100)

        let ok = TransactionForm.apply(
            to: tx, amountText: "250", originalText: "", showOriginal: false,
            kind: .expense, category: nil, paymentMethod: nil, date: date, note: ""
        )
        XCTAssertTrue(ok)
        XCTAssertEqual(tx.actualAmount, 250)

        let s = summary(date)
        XCTAssertEqual(s.dailySpending, 250)
        XCTAssertEqual(s.expenseView, 250)            // 无房贷利息
        XCTAssertEqual(s.cashOutflowView, 250)        // 无房贷还款
    }

    // MARK: - T-4 改分类写回

    func testT4_EditCategoryWriteBack() throws {
        let date = dayInThisMonth()
        let food = Category(name: "餐饮", icon: "fork.knife", kind: .expense)
        let shop = Category(name: "购物", icon: "bag.fill", kind: .expense)
        context.insert(food); context.insert(shop)

        let tx = Transaction(date: date, actualAmount: 30, kind: .expense, category: food)
        context.insert(tx)

        TransactionForm.apply(
            to: tx, amountText: "30", originalText: "", showOriginal: false,
            kind: .expense, category: shop, paymentMethod: nil, date: date, note: ""
        )
        XCTAssertIdentical(tx.category, shop)
        XCTAssertEqual(tx.category?.name, "购物")
    }

    // MARK: - T-5 改支付方式写回 + 最省的卡按新归属

    func testT5_EditPaymentMethodWriteBackAndTopSaving() throws {
        let date = dayInThisMonth()
        let cardA = PaymentMethod(name: "卡A", type: .creditCard)
        let cardB = PaymentMethod(name: "卡B", type: .creditCard)
        context.insert(cardA); context.insert(cardB)

        // 一笔有优惠的交易，初始归卡A。
        let tx = Transaction(date: date, actualAmount: 80, originalAmount: 100, kind: .expense, paymentMethod: cardA)
        context.insert(tx)
        XCTAssertEqual(summary(date).topSavingMethodName, "卡A")

        TransactionForm.apply(
            to: tx, amountText: "80", originalText: "100", showOriginal: true,
            kind: .expense, category: nil, paymentMethod: cardB, date: date, note: ""
        )
        XCTAssertIdentical(tx.paymentMethod, cardB)
        let s = summary(date)
        XCTAssertEqual(s.topSavingMethodName, "卡B")
        XCTAssertEqual(s.topSavingAmount, 20)
    }

    // MARK: - T-6 补/去原价 → discount 与 discountTotal

    func testT6_AddAndRemoveOriginalAmount() throws {
        let date = dayInThisMonth()
        let tx = Transaction(date: date, actualAmount: 70, kind: .expense)
        context.insert(tx)
        XCTAssertEqual(tx.discount, 0)
        XCTAssertEqual(summary(date).discountTotal, 0)

        // 补原价 100（>实付）
        TransactionForm.apply(
            to: tx, amountText: "70", originalText: "100", showOriginal: true,
            kind: .expense, category: nil, paymentMethod: nil, date: date, note: ""
        )
        XCTAssertEqual(tx.originalAmount, 100)
        XCTAssertEqual(tx.discount, 30)
        XCTAssertEqual(summary(date).discountTotal, 30)

        // 去掉原价（showOriginal=false → originalAmount=nil）
        TransactionForm.apply(
            to: tx, amountText: "70", originalText: "100", showOriginal: false,
            kind: .expense, category: nil, paymentMethod: nil, date: date, note: ""
        )
        XCTAssertNil(tx.originalAmount)
        XCTAssertEqual(tx.discount, 0)
        XCTAssertEqual(summary(date).discountTotal, 0)
    }

    // MARK: - T-7 kind expense→income 不再计入支出口径

    func testT7_KindExpenseToIncomeDropsFromExpenseView() throws {
        let date = dayInThisMonth()
        let tx = Transaction(date: date, actualAmount: 500, kind: .expense)
        context.insert(tx)
        XCTAssertEqual(summary(date).dailySpending, 500)

        TransactionForm.apply(
            to: tx, amountText: "500", originalText: "", showOriginal: false,
            kind: .income, category: nil, paymentMethod: nil, date: date, note: ""
        )
        XCTAssertEqual(tx.kind, .income)
        let s = summary(date)
        XCTAssertEqual(s.dailySpending, 0)      // 收入不计支出口径
        XCTAssertEqual(s.expenseView, 0)
    }

    // MARK: - T-9 canSave 校验

    func testT9_CanSaveRules() {
        XCTAssertFalse(TransactionForm.canSave(amountText: ""))
        XCTAssertFalse(TransactionForm.canSave(amountText: "0"))
        XCTAssertFalse(TransactionForm.canSave(amountText: "-1"))
        XCTAssertFalse(TransactionForm.canSave(amountText: "abc"))
        XCTAssertTrue(TransactionForm.canSave(amountText: "0.01"))
        XCTAssertTrue(TransactionForm.canSave(amountText: "1,234.50"))   // 千分位可解析
    }

    /// 金额非法时 apply 不写回、返回 false。
    func testApplyRejectsInvalidAmount() throws {
        let date = dayInThisMonth()
        let tx = Transaction(date: date, actualAmount: 100, kind: .expense)
        context.insert(tx)
        let ok = TransactionForm.apply(
            to: tx, amountText: "0", originalText: "", showOriginal: false,
            kind: .expense, category: nil, paymentMethod: nil, date: date, note: ""
        )
        XCTAssertFalse(ok)
        XCTAssertEqual(tx.actualAmount, 100)    // 未被改动
    }

    // MARK: - T-11 双模式不串味：编辑写回不新增记录数

    func testT11_EditDoesNotInsertNewRow() throws {
        let date = dayInThisMonth()
        let tx = Transaction(date: date, actualAmount: 100, kind: .expense)
        context.insert(tx)
        try context.save()
        XCTAssertEqual(try TestContext.count(Transaction.self, in: context), 1)

        // 编辑写回（apply 不 insert）
        TransactionForm.apply(
            to: tx, amountText: "300", originalText: "", showOriginal: false,
            kind: .expense, category: nil, paymentMethod: nil, date: date, note: "改了"
        )
        try context.save()
        XCTAssertEqual(try TestContext.count(Transaction.self, in: context), 1)  // 仍是 1 条
        XCTAssertEqual(tx.actualAmount, 300)
        XCTAssertEqual(tx.note, "改了")
    }

    // MARK: - T-25 编辑/删除后两口径独立（含房贷月份）

    func testT25_TwoViewsIndependentWithLoan() throws {
        let date = dayInThisMonth()
        // 一笔消费 200
        let tx = Transaction(date: date, actualAmount: 200, kind: .expense)
        context.insert(tx)
        // 一笔房贷还款：本金 800 + 利息 100，总 900
        let pay = LoanPayment(date: date, totalAmount: 900, principal: 800, interest: 100)
        context.insert(pay)

        var s = summary(date)
        XCTAssertEqual(s.expenseView, 300)        // 消费 200 + 利息 100
        XCTAssertEqual(s.cashOutflowView, 1100)   // 消费 200 + 还款全额 900

        // 编辑消费金额 200→500
        TransactionForm.apply(
            to: tx, amountText: "500", originalText: "", showOriginal: false,
            kind: .expense, category: nil, paymentMethod: nil, date: date, note: ""
        )
        s = summary(date)
        XCTAssertEqual(s.expenseView, 600)        // 500 + 100
        XCTAssertEqual(s.cashOutflowView, 1400)   // 500 + 900
        // 利息/还款不受交易编辑影响
        XCTAssertEqual(s.loanInterest, 100)
        XCTAssertEqual(s.loanTotalPaid, 900)

        // 删除消费交易
        context.delete(tx)
        s = summary(date)
        XCTAssertEqual(s.expenseView, 100)        // 仅利息
        XCTAssertEqual(s.cashOutflowView, 900)    // 仅还款全额
    }

    // MARK: - T-26 Decimal 往返无浮点误差 + discount 不落库

    func testT26_DecimalRoundTripNoFloatError() {
        // 0.1 + 0.2 类用例
        let v = Decimal(string: "0.30")!
        let s = TransactionForm.amountString(v)
        XCTAssertEqual(TransactionForm.parseAmount(s), v)

        // 多个值往返互逆
        for raw in ["0.01", "1", "99.99", "1234.56", "1000000", "0.30"] {
            let dec = Decimal(string: raw)!
            let str = TransactionForm.amountString(dec)
            XCTAssertEqual(TransactionForm.parseAmount(str), dec, "round-trip failed for \(raw)")
            XCTAssertFalse(str.contains(","), "string must have no thousands separators: \(str)")
        }
    }

    func testT26_DiscountIsDerivedNotStored() throws {
        let date = dayInThisMonth()
        // discount 由 originalAmount/actualAmount 计算；改实付后 discount 立刻随动（说明非落库快照）。
        let tx = Transaction(date: date, actualAmount: 80, originalAmount: 100, kind: .expense)
        context.insert(tx)
        XCTAssertEqual(tx.discount, 20)
        tx.actualAmount = 90
        XCTAssertEqual(tx.discount, 10)   // 派生重算
        tx.actualAmount = 120             // 实付高于原价 → 无优惠
        XCTAssertEqual(tx.discount, 0)
    }

    /// 双模式不串味（写回方向）：apply 改 kind 后，对象 kind 更新且记录数不变。
    func testEditModeRoundTripAllFields() throws {
        let date = dayInThisMonth()
        let cat = Category(name: "工资", icon: "yensign.circle.fill", kind: .income)
        let pm = PaymentMethod(name: "银行卡", type: .bankCard)
        context.insert(cat); context.insert(pm)

        let tx = Transaction(date: .now, actualAmount: 1, kind: .expense)
        context.insert(tx)

        let newDate = dayInThisMonth(20)
        TransactionForm.apply(
            to: tx, amountText: "8888.88", originalText: "9999.99", showOriginal: true,
            kind: .income, category: cat, paymentMethod: pm, date: newDate, note: "年终奖"
        )
        XCTAssertEqual(tx.actualAmount, Decimal(string: "8888.88"))
        XCTAssertEqual(tx.originalAmount, Decimal(string: "9999.99"))
        XCTAssertEqual(tx.kind, .income)
        XCTAssertIdentical(tx.category, cat)
        XCTAssertIdentical(tx.paymentMethod, pm)
        XCTAssertEqual(tx.note, "年终奖")
        XCTAssertEqual(tx.date, newDate)
    }
}
