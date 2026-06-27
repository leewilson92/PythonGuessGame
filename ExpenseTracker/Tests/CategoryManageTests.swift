import XCTest
import SwiftData
@testable import ExpenseTracker

// 消歧：`Category` 与 objc/runtime.h 的 `Category` 同名，显式指向本模型。
private typealias Category = ExpenseTracker.Category

/// 分类管理（增 / 改 / 删 / 排序）+ `.nullify` 不变量 的白盒测试。
final class CategoryManageTests: XCTestCase {

    private var context: ModelContext!

    override func setUpWithError() throws {
        context = try TestContext.make()
    }

    override func tearDown() { context = nil }

    private func fetchCategories() throws -> [Category] {
        try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortIndex)]))
    }

    // MARK: - T-13 新增分类可查到

    func testT13_AddCategoryQueryable() throws {
        let c = Category(name: "宠物", icon: "pawprint.fill", kind: .expense, sortIndex: 0)
        context.insert(c)
        try context.save()

        let expenses = try fetchCategories().filter { $0.kind == .expense }
        XCTAssertTrue(expenses.contains { $0.name == "宠物" && $0.icon == "pawprint.fill" })
    }

    // MARK: - T-14 改名 → 引用它的交易即时为新名

    func testT14_RenameReflectsInReferencingTransaction() throws {
        let c = Category(name: "餐饮", icon: "fork.knife", kind: .expense)
        context.insert(c)
        let tx = Transaction(actualAmount: 30, kind: .expense, category: c)
        context.insert(tx)
        try context.save()

        c.name = "吃饭"   // 模拟编辑写回
        XCTAssertEqual(tx.category?.name, "吃饭")   // 同一对象引用，无需迁移
    }

    // MARK: - T-15 删除未被引用分类

    func testT15_DeleteUnreferencedCategory() throws {
        let c = Category(name: "临时", icon: "tag.fill", kind: .expense)
        context.insert(c)
        try context.save()
        XCTAssertEqual(try TestContext.count(Category.self, in: context), 1)

        context.delete(c)
        try context.save()
        let remaining = try fetchCategories()
        XCTAssertFalse(remaining.contains { $0.name == "临时" })
        XCTAssertEqual(remaining.count, 0)
    }

    // MARK: - T-16 删除被引用分类 → .nullify，金额/汇总不变

    func testT16_DeleteReferencedCategoryNullifiesKeepsAmountAndSummary() throws {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: .now); comps.day = 10
        let date = cal.date(from: comps) ?? .now

        let c = Category(name: "购物", icon: "bag.fill", kind: .expense)
        context.insert(c)
        let tx = Transaction(date: date, actualAmount: 88, originalAmount: 120, kind: .expense, category: c)
        context.insert(tx)
        try context.save()

        let before = MonthlySummary.make(month: date,
                                         transactions: try context.fetch(FetchDescriptor<Transaction>()),
                                         loanPayments: [])
        XCTAssertEqual(before.dailySpending, 88)
        XCTAssertEqual(before.discountTotal, 32)

        // 删除被引用分类
        context.delete(c)
        try context.save()

        // 交易仍在，category 置空（.nullify），金额/优惠不变
        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 1)
        XCTAssertNil(txs[0].category)
        XCTAssertEqual(txs[0].actualAmount, 88)
        XCTAssertEqual(txs[0].discount, 32)

        let after = MonthlySummary.make(month: date, transactions: txs, loanPayments: [])
        XCTAssertEqual(after.dailySpending, before.dailySpending)
        XCTAssertEqual(after.discountTotal, before.discountTotal)
        XCTAssertEqual(after.expenseView, before.expenseView)
        XCTAssertEqual(after.cashOutflowView, before.cashOutflowView)
    }

    // MARK: - T-17 排序写回 sortIndex 段内连续 + 新顺序

    func testT17_ReorderWritesContiguousSortIndex() throws {
        // 支出段：A(0) B(1) C(2)
        let a = Category(name: "A", icon: "circle.fill", kind: .expense, sortIndex: 0)
        let b = Category(name: "B", icon: "circle.fill", kind: .expense, sortIndex: 1)
        let cc = Category(name: "C", icon: "circle.fill", kind: .expense, sortIndex: 2)
        // 收入段，不应被支出段排序影响
        let inc = Category(name: "工资", icon: "yensign.circle.fill", kind: .income, sortIndex: 0)
        [a, b, cc, inc].forEach { context.insert($0) }
        try context.save()

        let expenses = try fetchCategories().filter { $0.kind == .expense }
        XCTAssertEqual(expenses.map(\.name), ["A", "B", "C"])

        // 把第 0 项移动到末尾后位置（move offsets [0] -> 3）→ 期望 B, C, A
        SortReorder.apply(expenses, from: IndexSet(integer: 0), to: 3, sortIndex: \Category.sortIndex)
        try context.save()

        let reordered = try fetchCategories().filter { $0.kind == .expense }
        XCTAssertEqual(reordered.map(\.name), ["B", "C", "A"])
        XCTAssertEqual(reordered.map(\.sortIndex), [0, 1, 2])   // 段内连续

        // 收入段不受影响
        let incomes = try fetchCategories().filter { $0.kind == .income }
        XCTAssertEqual(incomes.map(\.name), ["工资"])
        XCTAssertEqual(incomes.first?.sortIndex, 0)
    }

    // MARK: - 新增 sortIndex = 该 kind 现有最大 +1（编辑视图保存逻辑的等价核对）

    func testNewCategorySortIndexIsMaxPlusOne() throws {
        let a = Category(name: "A", icon: "circle.fill", kind: .expense, sortIndex: 0)
        let b = Category(name: "B", icon: "circle.fill", kind: .expense, sortIndex: 5)
        context.insert(a); context.insert(b)
        try context.save()

        let expenses = try fetchCategories().filter { $0.kind == .expense }
        let nextIndex = (expenses.map(\.sortIndex).max() ?? -1) + 1
        XCTAssertEqual(nextIndex, 6)
    }

    // MARK: - IconCatalog 必含 SeedData 全部图标（保证种子项编辑命中高亮）

    func testIconCatalogCoversSeedIcons() {
        let seedCategoryIcons = [
            "fork.knife", "car.fill", "bag.fill", "house.fill", "building.2.fill",
            "antenna.radiowaves.left.and.right", "gamecontroller.fill",
            "cross.case.fill", "gift.fill", "yensign.circle.fill", "ellipsis.circle.fill",
        ]
        let catalog = Set(IconCatalog.all)
        for icon in seedCategoryIcons {
            XCTAssertTrue(catalog.contains(icon), "IconCatalog 缺少种子分类图标：\(icon)")
        }
        // 支付方式默认图标
        for type in PaymentType.allCases {
            XCTAssertTrue(catalog.contains(type.defaultIcon), "IconCatalog 缺少支付方式默认图标：\(type.defaultIcon)")
        }
        // 去重：无重复项
        XCTAssertEqual(IconCatalog.all.count, catalog.count)
    }
}
