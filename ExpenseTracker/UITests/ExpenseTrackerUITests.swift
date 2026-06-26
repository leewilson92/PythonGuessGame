import XCTest

/// 核心流程 UI 自动化（XCUITest）。
///
/// 程序化驱动模拟器做功能验收，不占用物理屏幕/鼠标键盘、可重复跑。
/// 用 `-uitest` 启动参数让 App 走内存容器 + 首启种子（见 `ExpenseTrackerApp`），
/// 每条用例从干净已知状态开始，不依赖既有持久化数据。
final class ExpenseTrackerUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
    }

    override func tearDown() {
        app = nil
    }

    // MARK: - 公共帮助器

    /// 当前默认就是「记账」Tab；用一个唯一金额便于后续断言定位。
    /// 记一笔：点「+」→ 输金额 → 选分类「餐饮」→ 保存。
    private func addTransaction(amount: String, category: String = "餐饮") {
        let addButton = app.buttons["add-transaction-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "列表右上「+」应可见")
        addButton.tap()

        let amountField = app.textFields["amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "金额输入框应出现")
        amountField.tap()
        amountField.typeText(amount)

        // 收起键盘，露出下方分类宫格（键盘工具栏有「完成」）。
        dismissKeyboardIfPresent()

        // 分类宫格按钮（label 取自分类名）。
        let categoryButton = app.buttons[category]
        XCTAssertTrue(categoryButton.waitForExistence(timeout: 5), "分类「\(category)」应可选")
        categoryButton.tap()

        let saveButton = app.buttons["保存"]
        XCTAssertTrue(saveButton.isEnabled, "金额合法时「保存」应可点")
        saveButton.tap()
    }

    /// 列表里这笔交易的「金额文案」静态文本（支出展示为 `-¥<amount>`）。
    /// 用「以 `-` 开头且包含金额」匹配，避免命中日期分组头里的「支出 ¥<amount>」。
    private func transactionAmountText(amount: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "-", amount)
        return app.staticTexts.containing(predicate).element(boundBy: 0)
    }

    /// 列表里承载这笔交易的可点击行。NavigationLink 行被无障碍合并成一个 Button
    /// （label 形如「餐饮、微信、-¥120.00」），点它进详情页。日期分组头不是 Button，天然排除。
    private func transactionRow(amount: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS %@", "-¥" + amount)
        return app.buttons.containing(predicate).element(boundBy: 0)
    }

    /// 在「记一笔」表单里展开支付方式 Picker 并选指定项。
    /// Form 内菜单式 Picker 呈现为单个 Button，其 label 是「标题、当前值」合并文案
    /// （形如「支付方式、微信」），故按 label 含「支付方式」命中，不能按精确「支付方式」。
    /// 点开后弹出选项菜单，点对应项；选中后自动收起。先收键盘避免遮挡。
    private func selectPaymentMethod(_ name: String) {
        dismissKeyboardIfPresent()
        let pickerPredicate = NSPredicate(format: "label CONTAINS %@", "支付方式")
        let picker = app.buttons.containing(pickerPredicate).element(boundBy: 0)
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "应有「支付方式」选择器")
        picker.tap()

        let option = app.buttons[name]
        XCTAssertTrue(option.waitForExistence(timeout: 5), "支付方式选项「\(name)」应可选")
        option.tap()
    }

    /// 打开「有优惠（记原价）」开关。Form 内 Toggle 的整行 Switch 用 `tap()` 点在 label 区不生效，
    /// 改点行内右侧（控件区）坐标，并断言确实翻到 on，露出下方「原价」输入框。
    private func turnOnDiscountToggle() {
        let toggle = app.switches["有优惠（记原价）"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "应有「有优惠（记原价）」开关")
        if toggle.value as? String == "1" { return }
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.textFields["original-field"].waitForExistence(timeout: 5),
                      "打开优惠开关后应出现「原价」输入框")
    }

    // MARK: - 用例 1：新增交易

    func testAddTransaction() throws {
        // 起始空态文案应在（内存容器无历史交易）。
        XCTAssertTrue(app.staticTexts["还没有账目"].waitForExistence(timeout: 5),
                      "干净启动时应显示空态「还没有账目」")

        addTransaction(amount: "88.00")

        // 回到列表，断言这笔金额出现。
        let amountText = transactionAmountText(amount: "88.00")
        XCTAssertTrue(amountText.waitForExistence(timeout: 5), "保存后列表应出现金额 88.00 的交易")
    }

    // MARK: - 用例 2：编辑交易（改金额、不新增行数）

    func testEditTransaction() throws {
        addTransaction(amount: "120.00")

        let row = transactionRow(amount: "120.00")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "应先有一笔 120.00")
        row.tap()

        // 进入详情页，点「编辑」。
        let editButton = app.buttons["编辑"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "详情页应有「编辑」")
        editButton.tap()

        // 改金额：清空再输新值。decimalPad 无文本选择，先清掉旧字符。
        let amountField = app.textFields["amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "编辑表单应有金额框")
        amountField.tap()
        clearText(amountField)
        amountField.typeText("99.00")

        dismissKeyboardIfPresent()
        app.buttons["保存"].tap()

        // 保存后退回列表层级，核对新值/旧值/行数。
        navigateBackToList()

        let newAmount = transactionAmountText(amount: "99.00")
        XCTAssertTrue(newAmount.waitForExistence(timeout: 5), "编辑后应显示新金额 99.00")

        // 只数「行金额」（以 `-` 开头），避免把日期分组头「支出 ¥99.00」也算进来。
        let newRowPredicate = NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "-", "99.00")
        XCTAssertEqual(app.staticTexts.containing(newRowPredicate).count, 1,
                       "编辑应改值而非新增行：行金额 -¥99.00 只应出现一次")

        let oldRowPredicate = NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "-", "120.00")
        XCTAssertEqual(app.staticTexts.containing(oldRowPredicate).count, 0,
                       "旧金额 120.00 应已被覆盖、不再有该行")
    }

    // MARK: - 用例 3：「我的」Tab → 分类管理 → 看到种子分类

    func testProfileAndCategoryManage() throws {
        let profileTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5), "应有「我的」Tab")
        profileTab.tap()

        let categoryEntry = app.buttons["分类管理"]
        XCTAssertTrue(categoryEntry.waitForExistence(timeout: 5), "「我的」里应有「分类管理」入口")
        categoryEntry.tap()

        // 分类管理页应列出种子分类（如「餐饮」「交通」）。
        XCTAssertTrue(app.staticTexts["餐饮"].waitForExistence(timeout: 5), "分类管理应显示种子分类「餐饮」")
        XCTAssertTrue(app.staticTexts["交通"].exists, "分类管理应显示种子分类「交通」")
    }

    // MARK: - 用例 4（可选）：删到空 → 空态文案

    func testDeleteToEmpty() throws {
        addTransaction(amount: "66.00")

        let row = transactionRow(amount: "66.00")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "应先有一笔 66.00")
        row.tap()

        // 详情页底部「删除」→ confirmationDialog 二次确认里再点「删除」。
        let detailDelete = app.buttons["删除"]
        XCTAssertTrue(detailDelete.waitForExistence(timeout: 5), "详情页应有「删除」")
        detailDelete.tap()

        // 等待对话框出现：此时会有两个「删除」按钮，详情页那个被遮挡变不可点，
        // 对话框里的那个可点。挑当前「可点」的「删除」点下去。
        tapHittableDelete()

        XCTAssertTrue(app.staticTexts["还没有账目"].waitForExistence(timeout: 5),
                      "删空后应回到空态「还没有账目」")
    }

    // MARK: - 用例 5：记一笔显式选支付方式 → 详情页可见

    /// 记一笔时显式选「支付宝」（避开默认首项「微信」），保存后点进详情断言显示「支付宝」。
    func testAddWithPaymentMethod() throws {
        let addButton = app.buttons["add-transaction-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "列表右上「+」应可见")
        addButton.tap()

        let amountField = app.textFields["amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "金额输入框应出现")
        amountField.tap()
        amountField.typeText("77.00")

        dismissKeyboardIfPresent()

        let categoryButton = app.buttons["餐饮"]
        XCTAssertTrue(categoryButton.waitForExistence(timeout: 5), "分类「餐饮」应可选")
        categoryButton.tap()

        selectPaymentMethod("支付宝")

        let saveButton = app.buttons["保存"]
        XCTAssertTrue(saveButton.isEnabled, "金额合法时「保存」应可点")
        saveButton.tap()

        // 点进这笔详情，断言支付方式行显示「支付宝」。
        let row = transactionRow(amount: "77.00")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "应先有一笔 77.00")
        row.tap()

        XCTAssertTrue(app.staticTexts["支付方式"].waitForExistence(timeout: 5), "详情页应有「支付方式」行")
        XCTAssertTrue(app.staticTexts["支付宝"].waitForExistence(timeout: 5),
                      "详情页支付方式应显示「支付宝」")
    }

    // MARK: - 用例 6：优惠（原价 > 实付）→ 列表「省 X」+ 详情「省下 X」

    /// 记一笔→开「有优惠（记原价）」→填原价 100（> 实付 60）→保存。
    /// 断言列表行出现「省 ¥40.00」，点进详情断言「省下 ¥40.00」。
    func testDiscountFlow() throws {
        let addButton = app.buttons["add-transaction-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "列表右上「+」应可见")
        addButton.tap()

        let amountField = app.textFields["amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "金额输入框应出现")
        amountField.tap()
        amountField.typeText("60.00")

        dismissKeyboardIfPresent()

        let categoryButton = app.buttons["餐饮"]
        XCTAssertTrue(categoryButton.waitForExistence(timeout: 5), "分类「餐饮」应可选")
        categoryButton.tap()

        // 打开优惠开关，露出「原价」输入框。
        turnOnDiscountToggle()

        let originalField = app.textFields["original-field"]
        XCTAssertTrue(originalField.waitForExistence(timeout: 5), "开优惠后应出现「原价」输入框")
        originalField.tap()
        originalField.typeText("100.00")

        dismissKeyboardIfPresent()
        app.buttons["保存"].tap()

        // 列表行（合并 Button）label 含「省 ¥40.00」。
        let savedRow = transactionRow(amount: "60.00")
        XCTAssertTrue(savedRow.waitForExistence(timeout: 5), "应先有一笔 60.00")
        let rowShowsDiscount = NSPredicate(format: "label CONTAINS %@", "省 ¥40.00")
        XCTAssertTrue(app.buttons.containing(rowShowsDiscount).element(boundBy: 0).waitForExistence(timeout: 5),
                      "列表该行应出现「省 ¥40.00」")

        // 进详情：断言「省下」行与金额。
        savedRow.tap()
        XCTAssertTrue(app.staticTexts["省下"].waitForExistence(timeout: 5), "详情页应有「省下」行")
        XCTAssertTrue(app.staticTexts["¥40.00"].waitForExistence(timeout: 5),
                      "详情页省下金额应为 ¥40.00")
    }

    // MARK: - 用例 7（AC-8）：编辑改金额后「取消」→ 列表保持原值

    /// 先有一笔 150 → 进编辑改成 250 → 点「取消」→ 断言列表仍是 150、且 250 未出现。
    func testEditCancelKeepsUnchanged() throws {
        addTransaction(amount: "150.00")

        let row = transactionRow(amount: "150.00")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "应先有一笔 150.00")
        row.tap()

        let editButton = app.buttons["编辑"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "详情页应有「编辑」")
        editButton.tap()

        let amountField = app.textFields["amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "编辑表单应有金额框")
        amountField.tap()
        clearText(amountField)
        amountField.typeText("250.00")

        dismissKeyboardIfPresent()

        // 点「取消」放弃改动（AddTransactionView 的 cancellationAction）。
        let cancelButton = app.buttons["取消"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "编辑表单应有「取消」")
        cancelButton.tap()

        // 退回列表层级核对。
        navigateBackToList()

        let oldAmount = transactionAmountText(amount: "150.00")
        XCTAssertTrue(oldAmount.waitForExistence(timeout: 5), "取消后应仍显示原金额 150.00")

        let oldRowPredicate = NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "-", "150.00")
        XCTAssertEqual(app.staticTexts.containing(oldRowPredicate).count, 1,
                       "取消编辑后原行 -¥150.00 应仍只有一条")

        let newRowPredicate = NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "-", "250.00")
        XCTAssertEqual(app.staticTexts.containing(newRowPredicate).count, 0,
                       "取消编辑后未保存的 250.00 不应出现")
    }

    // MARK: - 文本框/导航小工具

    /// 清空文本框：把光标移到末尾后逐字删除。decimalPad 无全选，用退格键。
    private func clearText(_ element: XCUIElement) {
        guard let value = element.value as? String, !value.isEmpty else { return }
        // 占位符 "0.00" 也会作为 value 返回；只删真实输入。
        if value == "0.00" { return }
        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
        element.typeText(deletes)
    }

    /// 从详情页/编辑流返回到列表根。优先点导航栏返回按钮。
    private func navigateBackToList() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists && backButton.isHittable {
            backButton.tap()
        }
    }

    /// 若键盘工具栏「完成」在，点它收起键盘，露出下方表单内容。
    private func dismissKeyboardIfPresent() {
        let done = app.buttons["完成"]
        if done.waitForExistence(timeout: 2), done.isHittable {
            done.tap()
        }
    }

    /// 点 confirmationDialog 里那个「可点」的「删除」（详情页同名按钮被遮挡、不可点）。
    /// 先等对话框标题「删除这笔账？」出现，再挑当前可点的「删除」，避免误点详情页按钮。
    private func tapHittableDelete() {
        let dialogTitle = app.staticTexts["删除这笔账？"]
        XCTAssertTrue(dialogTitle.waitForExistence(timeout: 5), "应弹出删除二次确认对话框")

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let deletes = app.buttons.matching(identifier: "删除")
            for i in 0..<deletes.count {
                let candidate = deletes.element(boundBy: i)
                if candidate.exists && candidate.isHittable {
                    candidate.tap()
                    return
                }
            }
            usleep(200_000) // 0.2s
        }
        XCTFail("未找到可点的删除二次确认按钮")
    }
}
