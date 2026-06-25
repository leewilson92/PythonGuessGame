import XCTest
import SwiftData
@testable import ExpenseTracker

/// 支付方式管理（增 / 改 / 删 / 排序）+ `.nullify` + 「最省的卡」重算 的白盒测试。
final class PaymentMethodManageTests: XCTestCase {

    private var context: ModelContext!

    override func setUpWithError() throws {
        context = try TestContext.make()
    }

    override func tearDown() { context = nil }

    private func fetchMethods() throws -> [PaymentMethod] {
        try context.fetch(FetchDescriptor<PaymentMethod>(sortBy: [SortDescriptor(\.sortIndex)]))
    }

    private func dayInThisMonth(_ day: Int = 12) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: .now); comps.day = day
        return cal.date(from: comps) ?? .now
    }

    // MARK: - T-20 新增支付方式可查到 + 默认图标随类型

    func testT20_AddMethodQueryableWithDefaultIcon() throws {
        // 未手动改图标时，图标 = type.defaultIcon（模型 init 行为）
        let m = PaymentMethod(name: "招行信用卡", type: .creditCard, sortIndex: 0)
        context.insert(m)
        try context.save()

        let methods = try fetchMethods()
        let added = methods.first { $0.name == "招行信用卡" }
        XCTAssertNotNil(added)
        XCTAssertEqual(added?.icon, PaymentType.creditCard.defaultIcon)
    }

    // MARK: - T-21 改名 → 引用它的交易即时更新 + 最省的卡用新名

    func testT21_RenameReflectsInTransactionAndTopSaving() throws {
        let date = dayInThisMonth()
        let m = PaymentMethod(name: "旧卡名", type: .creditCard)
        context.insert(m)
        let tx = Transaction(date: date, actualAmount: 60, originalAmount: 100, kind: .expense, paymentMethod: m)
        context.insert(tx)
        try context.save()

        func summaryNow() -> MonthlySummary {
            MonthlySummary.make(month: date,
                                transactions: (try? context.fetch(FetchDescriptor<Transaction>())) ?? [],
                                loanPayments: [])
        }
        XCTAssertEqual(summaryNow().topSavingMethodName, "旧卡名")

        m.name = "新卡名"   // 编辑写回
        XCTAssertEqual(tx.paymentMethod?.name, "新卡名")
        XCTAssertEqual(summaryNow().topSavingMethodName, "新卡名")
    }

    // MARK: - T-22 删除未被引用支付方式

    func testT22_DeleteUnreferencedMethod() throws {
        let m = PaymentMethod(name: "现金", type: .cash)
        context.insert(m)
        try context.save()
        XCTAssertEqual(try TestContext.count(PaymentMethod.self, in: context), 1)

        context.delete(m)
        try context.save()
        XCTAssertFalse(try fetchMethods().contains { $0.name == "现金" })
    }

    // MARK: - T-23 删被引用支付方式 → .nullify，金额/优惠不变，最省的卡按 ?? "未指定" 归并

    func testT23_DeleteReferencedMethodNullifiesAndRecomputesTopSaving() throws {
        let date = dayInThisMonth()
        let card = PaymentMethod(name: "卡X", type: .creditCard)
        context.insert(card)
        // 被该卡引用、有优惠的交易
        let tx = Transaction(date: date, actualAmount: 75, originalAmount: 100, kind: .expense, paymentMethod: card)
        context.insert(tx)
        try context.save()

        func summaryNow() -> MonthlySummary {
            MonthlySummary.make(month: date,
                                transactions: (try? context.fetch(FetchDescriptor<Transaction>())) ?? [],
                                loanPayments: [])
        }
        XCTAssertEqual(summaryNow().topSavingMethodName, "卡X")
        XCTAssertEqual(summaryNow().discountTotal, 25)

        // 删除被引用支付方式
        context.delete(card)
        try context.save()

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 1)
        XCTAssertNil(txs[0].paymentMethod)             // .nullify
        XCTAssertEqual(txs[0].actualAmount, 75)        // 金额不变
        XCTAssertEqual(txs[0].discount, 25)            // 优惠不变

        let s = summaryNow()
        XCTAssertEqual(s.discountTotal, 25)            // 优惠合计不变
        XCTAssertEqual(s.topSavingMethodName, "未指定")  // 已删项归并到「未指定」、不崩
        XCTAssertEqual(s.topSavingAmount, 25)
    }

    // MARK: - 排序写回（单段）

    func testReorderMethodsWritesContiguousSortIndex() throws {
        let a = PaymentMethod(name: "A", type: .wechat, sortIndex: 0)
        let b = PaymentMethod(name: "B", type: .alipay, sortIndex: 1)
        let c = PaymentMethod(name: "C", type: .bankCard, sortIndex: 2)
        [a, b, c].forEach { context.insert($0) }
        try context.save()

        // 把末项移到最前：move offsets [2] -> 0 → C, A, B
        let methods = try fetchMethods()
        SortReorder.apply(methods, from: IndexSet(integer: 2), to: 0, sortIndex: \PaymentMethod.sortIndex)
        try context.save()

        let reordered = try fetchMethods()
        XCTAssertEqual(reordered.map(\.name), ["C", "A", "B"])
        XCTAssertEqual(reordered.map(\.sortIndex), [0, 1, 2])
    }

    // MARK: - 新增 sortIndex = 现有最大 +1

    func testNewMethodSortIndexIsMaxPlusOne() throws {
        let a = PaymentMethod(name: "A", type: .wechat, sortIndex: 0)
        let b = PaymentMethod(name: "B", type: .alipay, sortIndex: 3)
        context.insert(a); context.insert(b)
        try context.save()
        let nextIndex = (try fetchMethods().map(\.sortIndex).max() ?? -1) + 1
        XCTAssertEqual(nextIndex, 4)
    }
}
