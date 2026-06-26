import XCTest
import SwiftData
@testable import ExpenseTracker

// 消歧：`Category` 与 objc/runtime.h 的 `Category` 同名，显式指向本模型。
private typealias Category = ExpenseTracker.Category

/// `Budget` 模型与「已用复用 `MonthlySummary` 口径」、备份往返的白盒测试。
/// 用内存 `ModelContext`（不依赖 UI）。覆盖设计第 6 节 B 组 B-8~B-14、C 组 B-15~B-17。
final class BudgetModelTests: XCTestCase {

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

    /// 上个月某一天。
    private func dayInLastMonth(_ day: Int = 15) -> Date {
        let cal = Calendar.current
        let lastMonth = cal.date(byAdding: .month, value: -1, to: .now) ?? .now
        var comps = cal.dateComponents([.year, .month], from: lastMonth)
        comps.day = day
        return cal.date(from: comps) ?? lastMonth
    }

    private func summary(_ month: Date) -> MonthlySummary {
        let tx = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let pays = (try? context.fetch(FetchDescriptor<LoanPayment>())) ?? []
        return MonthlySummary.make(month: month, transactions: tx, loanPayments: pays)
    }

    /// 复刻 `BudgetEditView` 保存时的「获取或创建」写入入口（fetch 有则改、无则插唯一一行）。
    /// 测试以同一语义驱动，确保「不新增行」「改值不增行」与视图一致。
    @discardableResult
    private func saveBudget(_ amount: Decimal) -> Budget {
        let existing = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        if let b = existing.first {
            b.monthlyAmount = amount
            return b
        } else {
            let b = Budget(monthlyAmount: amount)
            context.insert(b)
            return b
        }
    }

    /// 复刻「清除预算」：删第一行。
    private func clearBudget() {
        let existing = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        if let b = existing.first { context.delete(b) }
    }

    // MARK: - B-8 获取或创建：保存 / 改值都恰好 1 行

    func testB8_GetOrCreateKeepsSingleRow() throws {
        XCTAssertEqual(try TestContext.count(Budget.self, in: context), 0)

        // 首次保存 → 插入唯一一行
        saveBudget(2000)
        try context.save()
        XCTAssertEqual(try TestContext.count(Budget.self, in: context), 1)
        XCTAssertEqual((try context.fetch(FetchDescriptor<Budget>())).first?.monthlyAmount, 2000)

        // 再次「保存改值」为 1500 → 仍 1 行、值为 1500（不新增）
        saveBudget(1500)
        try context.save()
        XCTAssertEqual(try TestContext.count(Budget.self, in: context), 1)
        XCTAssertEqual((try context.fetch(FetchDescriptor<Budget>())).first?.monthlyAmount, 1500)
    }

    // MARK: - B-9 持久化：插入后 fetch 可查到

    func testB9_PersistAndFetch() throws {
        context.insert(Budget(monthlyAmount: 2000))
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<Budget>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.monthlyAmount, 2000)
    }

    // MARK: - B-10 清除：删除后 fetch 为空 → first == nil（空态）

    func testB10_ClearBudgetEmptiesTable() throws {
        saveBudget(2000)
        try context.save()
        XCTAssertEqual(try TestContext.count(Budget.self, in: context), 1)

        clearBudget()
        try context.save()
        XCTAssertEqual(try TestContext.count(Budget.self, in: context), 0)
        XCTAssertNil((try context.fetch(FetchDescriptor<Budget>())).first)
    }

    // MARK: - B-11 已用复用口径：含优惠 + 信用卡支付，used == 三笔实付之和

    func testB11_UsedReusesDailySpending() throws {
        let date = dayInThisMonth()
        let credit = PaymentMethod(name: "信用卡", type: .creditCard)
        context.insert(credit)

        // 三笔支出：一笔有原价优惠（实付 60，原价 100）、一笔信用卡支付（80）、一笔普通（200）
        context.insert(Transaction(date: date, actualAmount: 60, originalAmount: 100, kind: .expense))
        context.insert(Transaction(date: date, actualAmount: 80, kind: .expense, paymentMethod: credit))
        context.insert(Transaction(date: date, actualAmount: 200, kind: .expense))

        let used = summary(date).dailySpending
        XCTAssertEqual(used, 340)   // 60 + 80 + 200，实付口径（信用卡刷卡当时一次）

        saveBudget(2000)
        let status = BudgetStatus(budget: 2000, used: used)
        XCTAssertEqual(status.used, 340)
        XCTAssertEqual(status.remaining, 1660)
    }

    // MARK: - B-12 删 / 改交易后已用随动

    func testB12_UsedFollowsEditAndDelete() throws {
        let date = dayInThisMonth()
        let txA = Transaction(date: date, actualAmount: 800, kind: .expense)
        let txB = Transaction(date: date, actualAmount: 300, kind: .expense)
        context.insert(txA); context.insert(txB)
        saveBudget(2000)

        XCTAssertEqual(summary(date).dailySpending, 1100)
        XCTAssertEqual(BudgetStatus(budget: 2000, used: summary(date).dailySpending).remaining, 900)

        // 删掉 300 那笔 → 已用 800
        context.delete(txB)
        XCTAssertEqual(summary(date).dailySpending, 800)
        XCTAssertEqual(BudgetStatus(budget: 2000, used: summary(date).dailySpending).remaining, 1200)

        // 把 800 那笔改成 1500 → 已用 1500
        txA.actualAmount = 1500
        XCTAssertEqual(summary(date).dailySpending, 1500)
        XCTAssertEqual(BudgetStatus(budget: 2000, used: summary(date).dailySpending).remaining, 500)
    }

    // MARK: - B-13 自然月边界：上月支出不计入本月已用

    func testB13_NaturalMonthBoundary() throws {
        context.insert(Transaction(date: dayInLastMonth(), actualAmount: 999, kind: .expense))
        context.insert(Transaction(date: dayInThisMonth(), actualAmount: 100, kind: .expense))

        let used = summary(.now).dailySpending
        XCTAssertEqual(used, 100)   // 只含本月那笔，不含上月 999
        XCTAssertEqual(BudgetStatus(budget: 2000, used: used).remaining, 1900)
    }

    // MARK: - B-14 房贷利息不入已用；两口径仍各自正确

    func testB14_LoanInterestNotInUsed() throws {
        let date = dayInThisMonth()
        // 本月一笔消费 200
        context.insert(Transaction(date: date, actualAmount: 200, kind: .expense))
        // 本月一笔房贷还款：本金 800 + 利息 100，总 900
        context.insert(LoanPayment(date: date, totalAmount: 900, principal: 800, interest: 100))

        let s = summary(date)
        XCTAssertEqual(s.dailySpending, 200)        // 已用仅消费，不含利息、不含本金
        XCTAssertEqual(BudgetStatus(budget: 2000, used: s.dailySpending).used, 200)

        // 两个总口径未被预算污染、仍各自正确
        XCTAssertEqual(s.expenseView, 300)          // 消费 200 + 利息 100
        XCTAssertEqual(s.cashOutflowView, 1100)     // 消费 200 + 还款全额 900
    }

    // MARK: - B-15 含预算导出导入：快照含 budgetAmount，restore 后恢复且仍 1 行

    func testB15_BackupRoundTripWithBudget() throws {
        saveBudget(2000)
        try context.save()

        let data = try BackupManager.export(from: context)

        // 快照确含 budgetAmount == 2000
        let snapshot = try makeDecoder().decode(BackupManager.Snapshot.self, from: data)
        XCTAssertEqual(snapshot.budgetAmount, 2000)

        // 清空后 restore → Budget 恢复为 2000、且仍 1 行
        try BackupManager.restore(from: data, into: context)
        XCTAssertEqual(try TestContext.count(Budget.self, in: context), 1)
        XCTAssertEqual((try context.fetch(FetchDescriptor<Budget>())).first?.monthlyAmount, 2000)
    }

    // MARK: - B-16 旧备份兼容：无 budgetAmount 字段 → restore 不抛错、不创建 Budget

    func testB16_OldBackupWithoutBudgetField() throws {
        // 模拟旧版本备份 JSON：完全没有 budgetAmount 键
        let legacyJSON = """
        {
          "version": 1,
          "exportedAt": "2026-01-01T00:00:00Z",
          "categories": [],
          "paymentMethods": [],
          "transactions": [],
          "loans": []
        }
        """
        let data = Data(legacyJSON.utf8)

        // 解码不抛错、budgetAmount 为 nil
        let snapshot = try makeDecoder().decode(BackupManager.Snapshot.self, from: data)
        XCTAssertNil(snapshot.budgetAmount)

        // restore 不抛错、不创建 Budget（空 = 未设预算）
        XCTAssertNoThrow(try BackupManager.restore(from: data, into: context))
        XCTAssertEqual(try TestContext.count(Budget.self, in: context), 0)
        XCTAssertNil((try context.fetch(FetchDescriptor<Budget>())).first)
    }

    // MARK: - B-17 导入不产生多行：库内已有 Budget，导入带预算的备份后仍恰好 1 行

    func testB17_RestoreDoesNotDuplicateBudget() throws {
        // 库内先有一个 Budget(500)
        saveBudget(500)
        try context.save()
        XCTAssertEqual(try TestContext.count(Budget.self, in: context), 1)

        // 另造一份带预算 2000 的备份数据（来自一个临时上下文，避免污染当前）
        let exportData = try makeBackupData(budget: 2000)

        // restore（先清空含 Budget 再恢复）→ 结束后仍恰好 1 行、值为 2000
        try BackupManager.restore(from: exportData, into: context)
        XCTAssertEqual(try TestContext.count(Budget.self, in: context), 1)
        XCTAssertEqual((try context.fetch(FetchDescriptor<Budget>())).first?.monthlyAmount, 2000)
    }

    // MARK: - 备份解码 / 造数据帮助器

    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// 在一个独立内存上下文里设预算并导出，得到一份「带该预算」的备份数据。
    private func makeBackupData(budget: Decimal) throws -> Data {
        let tmp = try TestContext.make()
        tmp.insert(Budget(monthlyAmount: budget))
        try tmp.save()
        return try BackupManager.export(from: tmp)
    }
}
