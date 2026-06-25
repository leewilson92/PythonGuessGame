# 设计文档：补全 CRUD（交易 / 分类 / 支付方式）

> 由 `architect` 子agent 产出。对应 PRD：`docs/prd/crud-completion.md`（状态：已确认，2026-06-25）。
> 开发前需经人确认（流程门禁）。
> 状态：**已确认**（2026-06-25，含"详情页去掉记录时间"的决定）→ 可进 `developer`。

## 1. 目标与背景

把三类核心对象的 CRUD 补齐，将「能用」补成「好用」。属 **MVP 收尾**，不开新阶段、不碰 v2（资产/收入端/同步）。

- **交易**：列表行 → 只读详情页 → 「编辑」→ 全字段编辑（体验与「记一笔」一致）；详情页与列表左滑都能删。
- **分类 / 支付方式**：各自管理页，增 / 改 / 删 / 拖动排序；内置种子项也可改名·改图标·删除；图标从一组预置 SF Symbols 中选。
- **入口**：新增第 4 个 Tab「我的」，下挂 设置 / 分类管理 / 支付方式管理 / 数据备份，把现有但不可达的 `SettingsView` 纳入。

**范围内（本期做）**
- 交易：只读详情页 + 全字段编辑（复用「记一笔」字段集与交互）+ 保存后各处同步 + 详情页删除。
- 分类：增 / 改 / 删 / 排序的管理页；图标预置组选择；内置项可改可删。
- 支付方式：增 / 改 / 删 / 排序的管理页；类型可选、图标默认随类型可改。
- 「我的」Tab 信息架构落地，`SettingsView` 收入其中。

**明确不做 / 推迟（防范围蔓延）**
- 不改任何计费 / 汇总口径与房贷算法（不碰 `Finance/`、不碰两种口径定义）。
- 不做交易批量编辑 / 批量删除 / 多选 / 搜索 / 筛选 / 按分类看明细 / 复制再记一笔。
- 不做分类·支付方式的「合并并迁移历史」。
- **不新增任何模型字段**（删除策略 = `.nullify`，已确认；详见第 3 节核实结论）。
- 不改备份格式（`BackupManager` 不动）。
- 图标不做任意 SF Symbol 搜索/输入，只给预置组。

## 2. 影响的模块 / 文件

### 2.1 新增文件（均在 `ExpenseTracker/Sources/Views/`）

| 文件 | 作用 |
|---|---|
| `Settings/ProfileView.swift` | 「我的」Tab 根视图（`NavigationStack` + `List`，导航到下面四项） |
| `Transactions/TransactionDetailView.swift` | 交易只读详情页（金额大字 + 字段罗列 + 底部「编辑」「删除」） |
| `Settings/CategoryManageView.swift` | 分类管理页（按收/支分组列出、增/删/排序、进入编辑） |
| `Settings/CategoryEditView.swift` | 分类新增 / 编辑表单（名称 / 图标 / kind） |
| `Settings/PaymentMethodManageView.swift` | 支付方式管理页（列出、增/删/排序、进入编辑） |
| `Settings/PaymentMethodEditView.swift` | 支付方式新增 / 编辑表单（名称 / 类型 / 图标） |
| `Settings/IconPicker.swift` | 预置 SF Symbol 选择器（含 `IconCatalog` 常量集） + 复用控件 |

> `SettingsView.swift` 已存在（备份），不新建，仅由 `ProfileView` 以 `NavigationLink` 复用它的 Form 主体（见 5.6）。

### 2.2 修改文件

| 文件 | 改动 |
|---|---|
| `Views/RootView.swift` | TabView 从 3 个增到 4 个，新增「我的」Tab → `ProfileView()` |
| `Views/Transactions/TransactionListView.swift` | `TransactionRow` 包一层 `NavigationLink` 进详情页；左滑删除保留 |
| `Views/Transactions/AddTransactionView.swift` | 改造成 **新建 / 编辑双模式**（核心改动，见 5.1）；`applyDefaults` 仅新建模式生效 |
| `Views/Overview/OverviewView.swift` | **移除**右上角齿轮入口与 `showingSettings` / `.sheet { SettingsView() }`（设置改由「我的」Tab 进，避免双入口）。仅删 UI，不动汇总逻辑 |
| `Views/Settings/SettingsView.swift` | 适配在 `NavigationStack` 内被 push 使用：去掉自带 `NavigationStack` 包裹与「完成」按钮（见 5.6）。**备份逻辑零改动** |

### 2.3 可复用的现有类型 / 方法（不要重复造轮子）

- **金额格式化**：`Finance/Formatting.swift` 的 `Money.string(_:)`、`Money.percent(_:)`。详情页金额、优惠一律走它。
- **金额解析**：`AddTransactionView` 现有 `Decimal(string:)` 解析模式（去逗号），编辑模式沿用同一函数，禁止引入 `Double`。
- **枚举与标签**：`Models/Enums.swift` 的 `TransactionKind.label`、`PaymentType.label`、`PaymentType.defaultIcon`、各 `allCases`。分类编辑的 kind 选择、支付方式编辑的类型选择直接 `ForEach(...allCases)`。
- **派生值**：`Transaction.discount`（原价−实付）、`MonthlySummary`（`Finance/MonthlySummary.swift`）。详情页「省下」直接读 `tx.discount`，不重算。
- **删除规则**：三模型已配 `.nullify`（`Category.transactions` / `PaymentMethod.transactions` 反向 + `Transaction.category` / `Transaction.paymentMethod` 正向），删除联动无需新写规则。
- **种子数据**：`Seed/SeedData.swift` 的图标命名风格（`fork.knife` / `car.fill` …）作为 `IconCatalog` 选图标的参考来源。

## 3. 数据模型变更

**结论：本期不新增、不修改任何 `@Model` 字段，无数据迁移。** 逐项核实：

| 需求 | 现有支持 | 核实 |
|---|---|---|
| 分类增删改 | `Category(name, icon, kind, sortIndex)` 齐全 | ✅ 字段够用 |
| 支付方式增删改 | `PaymentMethod(name, type, icon?, sortIndex)` 齐全；`icon` 默认随 `type.defaultIcon` | ✅ 字段够用 |
| 交易全字段编辑 | `Transaction` 含 `date / actualAmount / originalAmount? / kind / category? / paymentMethod? / note` | ✅ 字段够用 |
| 排序 | 三模型均有 `sortIndex: Int` | ✅ 已存在，本期开始真正写入 |
| 删除被引用项 = 置空 | `Transaction.category` / `.paymentMethod` 均 `deleteRule: .nullify`；反向 `Category.transactions` / `PaymentMethod.transactions` 亦 `.nullify` | ✅ **现状即 PRD 决策**，无需改规则、无需加「归档」字段 |
| 记录时间展示（详情页） | **已确认去掉**：「日期」已显示该笔日期，"记录时间"重复且 `Transaction` 无 `createdAt`。详情页不展示记录时间。 | ✅ 去掉、不加字段 |

**备份兼容性**：`BackupManager` 的 DTO 仅序列化 `name / icon / kind|type / sortIndex`（及交易原始字段），不加字段即对备份零影响，`BackupManager.swift` 不改。

**`Identifiable` / 选择标识**：`AddTransactionView` 现用 `Category == c`、`PaymentMethod?.some(m)` 做 Picker/宫格选中判断，依赖 SwiftData 对象身份（`@Model` 默认 `Hashable`/`Identifiable`）。编辑模式预填时要拿到**当前 context 内的同一对象实例**（即 `transaction.category` / `transaction.paymentMethod` 本身），不要新建副本，否则宫格高亮/Picker 选中会失效。

## 4. 关键算法 / 公式

本期是纯 CRUD，**无新增财务算法**，不碰两种口径。仅有的"逻辑点"是排序写回与编辑保存：

### 4.1 排序写回（分类 / 支付方式通用）
- 管理页 `List` 配 `.onMove`，列表来源为 `@Query(sort: \.sortIndex)` 的数组（分类管理页按 kind 分两段，排序在**同一 kind 段内**进行）。
- `onMove(from:to:)`：取当前段的可变数组 → `move(fromOffsets:toOffset:)` → 重新遍历赋 `item.sortIndex = 新下标`（建议用该段的连续整数；段间不要求全局唯一，因为 `@Query` 排序在各自 `filter` 后稳定即可）。
- 写回后 SwiftData 自动持久化；所有 `@Query(sort: \.sortIndex)` 的视图（含「记一笔」分类宫格、支付方式 Picker）下次渲染自动按新序。

### 4.2 编辑保存（交易）
- 保存校验沿用 `canSave`：`amount != nil && amount > 0`。
- **新建模式**：`context.insert(Transaction(...))`（现状不变）。
- **编辑模式**：不 `insert`，直接把表单值写回传入的 `transaction` 各字段（`date / actualAmount / originalAmount / kind / category / paymentMethod / note`），SwiftData 自动保存。`originalAmount`：`showOriginal == false` 时写 `nil`（去掉优惠）。
- 派生值（`discount`、`MonthlySummary`）随原始字段变化自动重算，**不落库**。

### 4.3 边界条件
- 删除分类/支付方式到**空集合**：`filteredCategories.first` / `methods.first` 返回 `nil` → 选中为 `nil` → 记一笔时分类宫格空、支付方式显示「未指定」，不崩。
- 编辑模式下交易的 `category` 已被删（为 `nil`）：表单分类宫格无高亮，保存时按用户当前选择（可能仍为 `nil`），合法。
- 编辑模式切换 kind 后，原 `selectedCategory` 若 `kind` 不匹配 → 现有 `onChange(of: kind)` 已处理（置为 `filteredCategories.first`），编辑模式同样适用。

## 5. UI 流

### 5.1 交易编辑：改造 `AddTransactionView` 为双模式（核心）

**为什么不抽公共子视图**：现有 `AddTransactionView` 把 Form、`@State`、校验、保存、键盘焦点全耦合在一处且体积适中；PRD 要求编辑与「记一笔」体验**完全一致**。最低风险、最少重复的做法是给它加一个**可选的待编辑对象**，让同一视图承担两种模式，而非拆两份。

**方案：显式 `init` + `State(initialValue:)` 预填**

现状 `AddTransactionView` 无自定义 `init`，全部 `@State` 用字面量默认值，且靠 `applyDefaults()` 在 `onAppear` 补"今天/上次支付方式"。`@State` 的字面量默认值**无法被外部构造参数覆盖**（SwiftUI 限制），因此编辑模式必须：

1. 新增存储属性 `private let editing: Transaction?`（`nil` = 新建模式）。
2. 新增 `init(editing: Transaction? = nil)`：
   - 保存 `self.editing = editing`。
   - 当 `editing != nil`：用 `_kind = State(initialValue: tx.kind)`、`_amountText = State(initialValue: ...)`、`_originalText` / `_showOriginal`（`tx.originalAmount != nil`）、`_selectedCategory = State(initialValue: tx.category)`、`_selectedMethod = State(initialValue: tx.paymentMethod)`、`_date`、`_note` 逐一预填。
   - 当 `editing == nil`：维持现有字面量默认（`_amountText = State(initialValue:"")` 等），保持新建行为不变。
   - 金额回显：`amountText` 用 `tx.actualAmount` 转可编辑字符串（用 `NSDecimalNumber(decimal:).stringValue` 或等价，**保证 `Decimal(string:)` 能解析回去**，不经 `Double`）。`originalText` 同理。
3. `applyDefaults()` 改为 **仅新建模式执行**：方法首行 `guard editing == nil else { focusedField = .amount; return }`，避免编辑模式被"上次支付方式/今天"覆盖掉预填值。编辑模式仅设置键盘焦点。
4. `navigationTitle`：`editing == nil ? "记一笔" : "编辑"`。
5. `save()` 分支：
   - `editing == nil`：现状 `context.insert(...)`。
   - `editing != nil`：写回 `editing!` 的各字段（含 `originalAmount = original`，`original` 已是 `showOriginal ? ... : nil`），不 insert。
   - 两分支末尾都 `dismiss()`。
6. 调用方：
   - 列表「+」：`AddTransactionView()`（不传参，新建，行为不变）。
   - 详情页「编辑」：`AddTransactionView(editing: tx)`，以 `.sheet` 或 push 弹出（建议 `.sheet`，与「记一笔」同款模态体验一致）。

**回归要点**：改造后必须确认"记一笔"（新建路径）行为 100% 不变（默认今天、默认上次支付方式、键盘聚焦金额、分类默认首项）。

### 5.2 交易详情页 `TransactionDetailView`

- 入参 `let transaction: Transaction`。
- 顶部金额**大字**：`signed + Money.string(actualAmount)`，收入绿色 / 支出主色（沿用 `TransactionRow` 的符号与配色规则）。
- 字段区（`Form` 或 `List`）：收支类型（`kind.label`）、原价（有则显示 `Money.string(originalAmount)` + 「省下 `Money.string(discount)`」）、分类（`icon + name`，空 → 「未分类」）、支付方式（`name`，空 → 「未指定」）、日期（`tx.date` 格式化）、备注（空则不显示该行或显示占位）。**不展示"记录时间"**（已确认去掉，「日期」已覆盖）。
- `toolbar` 右上「编辑」→ 弹 `AddTransactionView(editing: transaction)`。
- 底部「删除」按钮（destructive）：`context.delete(transaction)` 后 `dismiss()` 返回列表。建议加二次确认 `confirmationDialog`（防误删，详情页删除更显眼）。

### 5.3 分类管理页 `CategoryManageView` + 编辑 `CategoryEditView`

- `@Query(sort: \Category.sortIndex)`，页面内按 `kind` 分两个 `Section`（支出 / 收入），每段内 `ForEach` + `.onMove`（排序限段内）+ `.onDelete`（左滑删，等价 `context.delete`）。
- 行：`icon + name`；点行 → push `CategoryEditView(editing: category)`。
- 右上「+」→ push/sheet `CategoryEditView(editing: nil)`（新增）。
- 顶部 `EditButton()`（进入 `EditMode` 才显示拖动手柄，符合系统习惯）。
- `CategoryEditView`：
  - 字段：名称 `TextField`、kind（`Picker(segmented)`，`TransactionKind.allCases`）、图标（`IconPicker`，见 5.5）。
  - **新增**：保存时 `Category(name:icon:kind:sortIndex:)`，`sortIndex` = 该 kind 现有最大 +1（或 count）。`context.insert`。
  - **编辑**：写回 `name / icon / kind`。**约束**：PRD 决策"分类自身 `kind` 不可改"——故**编辑模式下 kind 选择器禁用/隐藏**（只读展示当前 kind），仅新增模式可选 kind。
  - 校验：名称非空才可保存。

### 5.4 支付方式管理页 `PaymentMethodManageView` + 编辑 `PaymentMethodEditView`

- `@Query(sort: \PaymentMethod.sortIndex)`，单段 `List` + `.onMove` + `.onDelete` + `EditButton`。
- 行：`icon + name`（可附 `type.label` 次要文字）；点行 → `PaymentMethodEditView(editing: method)`；右上「+」→ 新增。
- `PaymentMethodEditView`：
  - 字段：名称 `TextField`、类型 `Picker`（`PaymentType.allCases`，显示 `label`）、图标（`IconPicker`）。
  - 类型改变时图标**联动建议值**：若用户未手动改过图标，类型变化时把图标更新为 `newType.defaultIcon`（与模型 `init` 默认行为一致）；用户手动选过则保留。
  - 新增：`PaymentMethod(name:type:icon:sortIndex:)`，`sortIndex = count`。编辑：写回 `name / type / icon`。
  - 校验：名称非空。

### 5.5 图标选择器 `IconPicker` + `IconCatalog`

- `IconCatalog`：一个常量集合（建议 `enum IconCatalog { static let all: [String] = [...] }` 或按用途分组的字典），收录一组**确定存在**的 SF Symbols（覆盖餐饮/交通/购物/居住/通讯/娱乐/医疗/人情/收入/卡片/现金/通用等），含 `SeedData` 现用的全部图标，保证种子项编辑时能在列表里命中高亮。
- `IconPicker`：`LazyVGrid` 展示 `IconCatalog.all`，当前选中高亮（复用 5.x 宫格高亮风格），点选写回绑定的 `icon`。不做搜索框、不接受任意输入（PRD 决策）。
- 复用：分类编辑、支付方式编辑共用同一个 `IconPicker`。

### 5.6 「我的」Tab `ProfileView` + 设置纳入

- `RootView` TabView 第 4 项：`ProfileView().tabItem { Label("我的", systemImage: "person.crop.circle") }`。
- `ProfileView`：`NavigationStack { List { ... } }`，行（`NavigationLink`）：
  1. 分类管理 → `CategoryManageView`
  2. 支付方式管理 → `PaymentMethodManageView`
  3. 数据备份 → `SettingsView`（适配后）
  - 标题「我的」。
- **`SettingsView` 适配**：现状它自带 `NavigationStack` + 右上「完成」`dismiss`（为当初的 `.sheet` 设计）。改为被 `ProfileView` push：去掉外层 `NavigationStack`（由 `ProfileView` 提供）、去掉「完成」按钮（push 用系统返回）。导航标题保留「设置」或改「数据备份」。**导入/导出/`BackupDocument`/fileExporter/fileImporter 逻辑一字不改。**
- **去重入口**：`OverviewView` 移除右上齿轮与 `.sheet { SettingsView() }`，避免设置出现在两处。

### 5.7 最少点击路径（守「记一笔要快」）
- 记一笔：与现状完全一致（Tab1 → +），本期不增加任何步骤。
- 改一笔：列表行点一下 → 详情 → 编辑 → 改 → 保存（与 PRD 期望一致）。
- 配置类（管理分类/支付方式）属低频，放第 4 Tab，不打扰日常记账。

## 6. 测试点清单（供 developer 写白盒测试）

> 标 **[单测]** 的可在 XCTest 纯逻辑覆盖（不依赖 UI）；标 **[Mac-功能]** 需 `verifier` 在模拟器上功能验证；**[Mac-回归]** 为不变量回归，必测。
> 纯逻辑单测主要落在「编辑保存写回」「排序写回 sortIndex」「删除 nullify 后派生值不变」三处——这些可在 `ModelContext`（内存容器）上直接驱动模型与 `MonthlySummary` 验证，无需 UI。

### 交易（映射 AC-1~10）
- T-1 **[Mac-功能]** AC-1：列表点交易行进入只读详情页，显示实付/分类/支付方式/日期/备注/收支类型；有原价时显示原价 + 「省下 X」。
- T-2 **[Mac-功能]** AC-2：详情页「编辑」进入表单，各字段（金额/分类/支付方式/日期/备注/kind/原价开关与值）正确回显。
- T-3 **[单测]** AC-3：构造一笔交易→走"编辑保存写回"逻辑把 `actualAmount` 改值→断言对象新值；`MonthlySummary.make` 的 `dailySpending`/`expenseView`/`cashOutflowView` 随之更新。**[Mac-功能]** 列表行金额、当日小计、概览数字 UI 同步。
- T-4 **[单测]** AC-4：改 `category`→断言 `transaction.category` 为新分类（id/name）。**[Mac-功能]** 列表行图标+名更新。
- T-5 **[单测]** AC-5：改 `paymentMethod`→断言写回；若有 discount，`MonthlySummary.topSavingMethodName` 按新归属重算。**[Mac-功能]** 概览「最省的卡」更新。
- T-6 **[单测]** AC-6：给无原价交易补 `originalAmount`（>实付）→ `discount`>0、`MonthlySummary.discountTotal` 增加；去掉原价（写 `nil`）→ `discount`=0、合计相应减少。**[Mac-功能]** 列表「省 X」出现/消失。
- T-7 **[单测]** AC-7：`kind` 由 expense→income→ `MonthlySummary.dailySpending`/`expenseView` 不再含该笔（收入不计支出口径）。**[Mac-功能]** 列表符号(-/+)与颜色更新。
- T-8 **[Mac-功能]** AC-8：编辑表单「取消」→ 原交易（及列表/概览）不变。
- T-9 **[单测]** AC-9 / FR-A5：`canSave` 规则——金额空 / "0" / "-1" → `false`；正值 → `true`（与「记一笔」同款）。**[Mac-功能]** 「保存」按钮置灰。
- T-10 **[Mac-回归]** AC-10：列表左滑删除仍可用，删后列表 + 概览同步。
- T-11 **[单测]** 编辑双模式不串味：`AddTransactionView(editing: nil)` 即新建（不预填、`save` 走 insert）；`editing: tx` 即编辑（预填、`save` 走写回不新增记录数）。可通过对 `ModelContext` 内 `Transaction` 计数验证"编辑不新增行"。

### 分类（映射 AC-11~16）
- T-12 **[Mac-功能]** AC-11：分类管理页列出全部分类（含种子项），按收/支分组。
- T-13 **[单测]** AC-12：新增分类（name/icon/kind）写入 context→ 按 `@Query(sort:\.sortIndex)` + `filter(kind==)` 能查到。**[Mac-功能]** 「记一笔」对应 kind 宫格出现该项。
- T-14 **[单测]** AC-13：改分类 `name`→ 引用它的 `Transaction.category?.name` 即时为新名（同一对象引用，无需迁移）。**[Mac-功能]** 管理列表 / 宫格 / 历史交易行三处显示更新。
- T-15 **[单测]** AC-14：删除未被引用分类→ `@Query` 结果不再含它。**[Mac-功能]** 宫格消失。
- T-16 **[单测]** AC-15（关键）：删除**被交易引用**的分类→ 该 `Transaction.category == nil`（`.nullify` 生效）；该交易 `actualAmount`/`discount` 不变；`MonthlySummary` 各值不变（金额不丢、口径不受影响）。**[Mac-功能]** 历史交易显示「未分类」。
- T-17 **[单测]** AC-16：调用排序写回逻辑（移动某段顺序）→ 段内各 `sortIndex` 连续且符合新序；再次 `@Query(sort:\.sortIndex)` 得到新顺序。**[Mac-功能]** 「记一笔」宫格排列随之改变。
- T-18 **[Mac-功能]** 分类编辑模式 kind 选择器为只读/禁用（不可改 kind，符合 PRD Q6 分类侧决策）。

### 支付方式（映射 AC-17~21）
- T-19 **[Mac-功能]** AC-17：支付方式管理页列出全部（含种子项）。
- T-20 **[单测]** AC-18：新增支付方式（含类型）写入→ `@Query` 可查到；图标默认为 `type.defaultIcon`（未手动改时）。**[Mac-功能]** 「记一笔」支付方式 Picker 出现该项。
- T-21 **[单测]** AC-19：改 `name`→ `Transaction.paymentMethod?.name` 即时更新；`MonthlySummary.topSavingMethodName` 若指向它则用新名。**[Mac-功能]** 管理列表 / Picker / 历史交易 / 概览「最省的卡」四处更新。
- T-22 **[单测]** AC-20：删未被引用支付方式→ `@Query` 不再含。**[Mac-功能]** Picker 消失。
- T-23 **[单测]** AC-21（关键）：删**被引用**支付方式→ `Transaction.paymentMethod == nil`；金额/优惠不变；`MonthlySummary` 重算「最省的卡」时按 `tx.paymentMethod?.name ?? "未指定"` 归并，忽略已删项（不崩、不串）。**[Mac-功能]** 历史交易显示「未指定」。

### 不变量回归（映射 AC-22~24，必测）
- T-24 **[Mac-回归]** AC-22：本期未引入任何"还卡/还贷"记账路径；信用卡消费仍只算一次支出。（静态核对 + 功能确认无新增写支出入口）
- T-25 **[单测]** AC-23：编辑/删除交易后，`MonthlySummary.expenseView`（消费+利息）与 `cashOutflowView`（含房贷全额）仍各自正确、互不混淆（构造含房贷还款的月份验证两值独立）。
- T-26 **[单测]** AC-24：全程金额用 `Decimal`；编辑金额经 `Decimal(string:)` 解析、`Money.string` 展示无浮点误差（如 `0.1+0.2` 类用例校验）；`discount` 派生计算未落库（模型无 discount 存储字段，确认）。

### 空态 / 健壮性（映射 FR-X2）
- T-27 **[Mac-功能]** 删空所有分类后进「记一笔」：分类宫格为空、不崩；保存一笔 `category==nil` 的交易合法。
- T-28 **[Mac-功能]** 删空所有支付方式后进「记一笔」：Picker 仅「未指定」、不崩。
- T-29 **[Mac-功能]** 设置页可达性回归：第 4 Tab「我的」→ 数据备份 → 导出/导入按钮可用（`SettingsView` 适配后功能不丢）；`OverviewView` 原齿轮入口移除后无残留。

## 7. 风险与取舍

- **R1 `AddTransactionView` 双模式改造引入回归**（最高关注）：改 `init` 与 `applyDefaults` 可能误伤"记一笔"默认值。**缓解**：`applyDefaults` 用 `guard editing == nil` 早返回；T-11 专测两模式不串味；developer 改后必须人肉走查新建流程一遍。
- **R2 金额字符串往返精度**：`Decimal → String → Decimal` 回显若经 `Double` 会丢精度。**取舍**：用 `NSDecimalNumber(decimal:).stringValue`（十进制字符串），与 `Decimal(string:)` 严格互逆，禁用 `String(format:)`/`Double`。T-26 守。
- **R3「记录时间」已确认去掉**（2026-06-25）：详情页不展示"记录时间"——「日期」已显示该笔日期，重复且 `Transaction` 无 `createdAt`。**不加字段、不迁移、备份零影响。** 若后续要"真实创建时间戳"，再单列改动。
- **R4 排序 `sortIndex` 段内 vs 全局**：分类按 kind 分两段排序，`sortIndex` 仅需段内有序（`@Query` 先全局按 `sortIndex` 排，再 `filter(kind==)`，段内相对顺序即生效）。**取舍**：不追求全局唯一连续，避免一次移动要重排所有项；只要每段内连续即可。
- **R5 双入口混乱**：保留 `OverviewView` 齿轮 + 新 Tab 会让"设置在哪"含糊。**决策**：移除概览齿轮，设置只走「我的」Tab（信息架构单一）。
- **R6 `@Query` 自动刷新依赖**：编辑/删除后概览刷新依赖 SwiftData `@Query` 自动更新（现状 `OverviewView`/`AddTransactionView` 都已这么用）。风险低，但 verifier 需实测 AC-3/5/6/7 的概览联动。
- **放弃的替代方案**：①「抽公共子视图」承载记一笔/编辑——比双模式 `init` 改动面更大、要重接焦点/工具栏，收益不抵风险，放弃。②删除被引用项用"禁止删除/软归档"——PRD 已定 `.nullify`，不引入归档字段。③图标任意 SF Symbol 搜索——PRD 定预置组，避免选到不存在符号。

### 产品不变量逐条核对（第 7 节门禁）
- **信用卡不重复计**：本期不新增任何"还卡"记账路径，刷卡仍只在当时记一次。✅ 不破坏。
- **房贷本金不算支出**：不碰 `Finance/`、不碰房贷，编辑交易与房贷无关。✅ 不破坏。
- **两种口径并存**：定义不变；编辑/删除后 `MonthlySummary.expenseView` / `cashOutflowView` 由 `@Query` 重算，T-25 守两值独立。✅ 不破坏。
- **金额一律 `Decimal`**：编辑沿用 `Decimal(string:)` 解析，回显用 `NSDecimalNumber.stringValue`，禁 `Double`。✅ 守住（R2/T-26）。
- **派生值计算得出不落库**：`discount`、`MonthlySummary`、负债剩余仍为计算属性；编辑只改原始字段；不新增任何派生存储字段。✅ 守住。
- **无网络/无注册/无广告/本地优先**：本期全部本地视图与 SwiftData 操作，不引入网络。✅ 守住。

## 8. 开发任务拆解（供 `developer` 按序执行）

> 每步可独立提交、独立编译通过。建议顺序遵循 PRD「先打通入口，再交易，再管理，再排序」。

- **S1 「我的」Tab + 设置可达**
  - 新建 `Settings/ProfileView.swift`（`NavigationStack + List`，先放"数据备份"一项，分类/支付方式管理用占位行或暂留 TODO）。
  - `RootView` 加第 4 Tab。
  - 适配 `SettingsView`（去 `NavigationStack`/「完成」，供 push）。
  - `OverviewView` 移除齿轮与 `.sheet { SettingsView() }`。
  - 自测：Tab 可见、设置可进、备份按钮在（T-29）。

- **S2 交易只读详情页**
  - 新建 `Transactions/TransactionDetailView.swift`（金额大字 + 字段 + 底部「删除」+ 右上「编辑」占位）。
  - `TransactionListView` 的 `TransactionRow` 外包 `NavigationLink → TransactionDetailView`，左滑删除保留。
  - 自测：点行进详情、字段/优惠/空态显示正确（T-1）；详情页删除返回（覆盖 AC-1 + 详情删除）。

- **S3 交易编辑（双模式改造，核心）**
  - 改造 `AddTransactionView`：加 `editing` 属性 + `init(editing:)` 预填 + `applyDefaults` 早返回 + `save` 分支 + 标题切换。
  - 详情页「编辑」接 `AddTransactionView(editing: tx)`。
  - 写白盒测试：T-3~T-7、T-9、T-11、T-25、T-26（编辑保存写回 + 校验 + 双模式不串味 + 不变量）。
  - 自测：回显、改各字段保存生效、取消不变、新建路径回归不变（T-2、T-8、R1）。

- **S4 分类管理（增 / 改 / 删）**
  - 新建 `Settings/IconPicker.swift`（含 `IconCatalog`，先服务分类）。
  - 新建 `CategoryManageView`（分组列出 + 增 + `.onDelete`）+ `CategoryEditView`（名称/图标，新增可选 kind、编辑只读 kind）。
  - `ProfileView` 接上"分类管理"。
  - 写白盒测试：T-13、T-14、T-15、T-16（含 `.nullify` 后 `MonthlySummary` 不变）。
  - 自测：T-12、T-18、AC-13 三处更新。

- **S5 支付方式管理（增 / 改 / 删）**
  - 新建 `PaymentMethodManageView` + `PaymentMethodEditView`（名称/类型/图标，类型联动默认图标），复用 `IconPicker`。
  - `ProfileView` 接上"支付方式管理"。
  - 写白盒测试：T-20、T-21、T-22、T-23（`.nullify` + 最省的卡重算）。
  - 自测：T-19、AC-19 四处更新。

- **S6 排序（分类 + 支付方式）**
  - 两管理页加 `EditButton` + `.onMove`，实现 `sortIndex` 段内写回。
  - 确认 `AddTransactionView` 宫格/Picker 的 `@Query(sort:\.sortIndex)` 随之生效（无需改它，仅验证）。
  - 写白盒测试：T-17（分类）+ 支付方式排序写回对称用例。
  - 自测：AC-16 + 「记一笔」排列随动。

- **S7 空态与回归收尾**
  - 走查 T-10、T-24、T-27、T-28、T-29 的空态 / 不变量 / 入口回归。
  - 交 `reviewer` 检视 → `verifier` Mac 端编译/单测/功能/性能。

---

### 给调用者的提示
设计文档已就绪：`docs/design/crud-completion.md`。核实结论——**本期无需新增/修改任何模型字段，无数据迁移**（`.nullify` 删除规则与 `sortIndex` 均为现状即满足）。共拆解 **7 个可独立提交的步骤（S1~S7）**。
按流程门禁，**需人确认本设计后**方可进入 `developer` 开发阶段。
