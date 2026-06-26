# 设计文档：月度预算

> 由 `architect` 子agent 产出。对应 PRD：`docs/prd/monthly-budget.md`（状态：已确认，2026-06-26，决策见其第 0 节）。
> 开发前需经人确认（流程门禁）。
> 状态：**已确认**（2026-06-26）→ 可进 `developer`。

## 1. 目标与背景

给极简记账 App 增加**单一月度总预算**：用户设一个「本月总支出上限」，概览即时显示「总预算 / 已用 / 剩余 / 超支」，让记账从"事后回看"具备"事前约束 / 进度感"。属**阶段 2 的第一个增量**（见 `ExpenseTracker/README.md` 路线图）。

本设计严格按 PRD 第 0 节锁定的 7 项决策落地，不重启已关闭的开放问题。

**范围内（本期做）**
1. 持久化一个全库唯一的「本月总预算金额」（`Decimal`，> 0）。
2. 概览新增一张「本月预算」卡：总预算 / 已用 / 剩余；到/超 100% 安静变红 + 文案「超支 ¥X」/「剩 ¥X」；未设预算显示友好空态。
3. 「我的」Tab（`ProfileView`）新增"预算"入口 → 设 / 改 / 清除总预算的简单页。
4. 「已用」复用 `MonthlySummary` 现有"仅支出类、自然月、信用卡不重复、不含房贷利息"口径。
5. 预算金额纳入备份导出 / 导入；导入旧备份（无预算字段）按"未设预算"处理、不崩。

**明确不做 / 推迟（防范围蔓延）**
- **不做分类预算**（PRD Q1：只做单一总预算；分类级留 backlog）。
- **不按月留历史、不结转剩余**（PRD Q3：只存一个"当前总预算金额"，每月按自然月自动重新计已用）。
- **不把房贷利息计入预算已用**（PRD Q6）；**绝不改动两个总口径**（本月支出 / 本月现金流出）的定义与数值。
- **不做 80% 黄色预警 / 进度分色梯度**（PRD Q4：本期只做 100% 红线；黄色预警留后续）。
- **不做记账时弹窗 / 拦截 / toast**（PRD Q6 不打扰）；不改 `AddTransactionView` 主路径。
- 不做预算图表 / 趋势 / 通知 / CSV 报表（PRD 第 6 节）。

## 2. 影响的模块 / 文件

### 2.1 新增文件

| 文件 | 作用 |
|---|---|
| `Sources/Models/Budget.swift` | 新 `@Model Budget { monthlyAmount: Decimal }`，全库唯一一行（单例式获取或创建）。 |
| `Sources/Finance/BudgetStatus.swift` | **纯逻辑**结构体：从「预算金额 + 本月已用」派生出已用 / 剩余 / 是否超支 / 进度比例 / 文案。可被 XCTest 直接驱动（无 UI、无 SwiftData）。 |
| `Sources/Views/Overview/BudgetCard.swift` | 概览「本月预算」卡视图（带进度条 + 变红 + 空态）。 |
| `Sources/Views/Settings/BudgetEditView.swift` | 「我的」Tab 下的设 / 改 / 清除总预算页。 |
| `Tests/BudgetStatusTests.swift` | `BudgetStatus` 纯逻辑单测（已用 / 剩余 / 超支 / 文案 / 边界）。 |
| `Tests/BudgetModelTests.swift` | `Budget` 获取或创建唯一实例、改值持久化、已用复用 `MonthlySummary` 口径、备份往返。 |

> `project.yml` 用 `sources: - path: Sources` / `path: Tests`（整目录纳入），新增 `.swift` 文件 `xcodegen generate` 后**自动进工程**，无需改 `project.yml`。

### 2.2 修改文件

| 文件 | 改动 |
|---|---|
| `Sources/ExpenseTrackerApp.swift` | `ModelContainer(for:)` 的 schema 列表**追加 `Budget.self`**（新 `@Model` 必须登记，否则无法持久化/查询）。其余不动。 |
| `Sources/Views/Overview/OverviewView.swift` | 新增 `@Query private var budgets: [Budget]`；在四张 `StatCard` 之后插入一张 `BudgetCard`。**原四张卡的数据来源与数值一字不改。** |
| `Sources/Views/Settings/ProfileView.swift` | 在第一个 `Section`（分类管理 / 支付方式管理）内新增一行"预算" `NavigationLink → BudgetEditView`，与"分类管理 / 支付方式管理"并列。 |
| `Sources/Backup/BackupManager.swift` | `Snapshot` 加可选字段 `budgetAmount: Decimal?`；导出时写入当前预算金额；导入时按它"获取或创建"`Budget`（缺省 / 旧备份为 `nil` → 不创建，等价未设预算）。 |
| `Tests/TestContext.swift` | `ModelContainer(for:)` 的 schema 列表**追加 `Budget.self`**（与 App 容器对齐，否则单测查询 `Budget` 会崩）。 |

### 2.3 可复用的现有类型 / 方法（不要重复造轮子）

- **本月已用来源**：`Finance/MonthlySummary.swift` 的 `MonthlySummary.make(...)` 已算出 `dailySpending`（仅支出类、自然月、信用卡不重复、不含房贷利息）——**这正是预算"已用"的口径**，直接取 `summary.dailySpending`，不另写过滤逻辑、不碰两种总口径。见 4.2。
- **金额格式化**：`Finance/Formatting.swift` 的 `Money.string(_:)`。预算卡与设预算页的金额展示一律走它。
- **金额解析 / 校验 / 往返**：`Views/Transactions/TransactionForm.swift` 的 `parseAmount(_:)`、`canSave(amountText:)`、`amountString(_:)`（全 `Decimal`、无 `Double`、十进制字符串往返互逆）。设预算页的金额输入框**直接复用**这三者，金额校验与「记一笔」同款（> 0）。
- **SwiftData 单例式获取**：参考 `Seed/SeedData.swift` 的 `fetch + isEmpty` 模式实现 `Budget` 的"获取或创建"（见 3.2）。
- **概览卡片视觉**：`OverviewView.swift` 内 `private struct StatCard`。预算卡因需进度条与变红，**新做 `BudgetCard`**（不强行复用 `StatCard`，理由见 5.1），但配色 / 圆角 / `secondarySystemBackground` 风格与 `StatCard` 保持一致。
- **测试基建**：`Tests/TestContext.swift`（内存 `ModelContext`、`count(_:in:)`）、现有 `TransactionEditTests`/`CategoryManageTests` 的 `dayInThisMonth()`、`summary(_:)` 帮助器写法直接照搬。

## 3. 数据模型变更

### 3.1 新增 `@Model Budget`

```
@Model
final class Budget {
    var monthlyAmount: Decimal   // 本月总支出上限，> 0
    init(monthlyAmount: Decimal) { self.monthlyAmount = monthlyAmount }
}
```

- **唯一字段** `monthlyAmount: Decimal`（守"金额一律 `Decimal`"）。
- **全库一行**：单一总预算、不按月留历史、不结转 → 只需一行存"当前预算金额"。已用按自然月在读取时派生，不随月份变多（PRD Q3）。
- **不存任何派生值**：剩余 / 超支 / 进度均由 `BudgetStatus` 计算，不落库（守"派生值不冗余存储"）。

### 3.2 唯一实例的"获取或创建"与避免多行

不引入"单例锁"机制（SwiftData 无此原语）；用**约定 + 单一写入入口**保证唯一：

- 读取：`@Query private var budgets: [Budget]`，业务上取 `budgets.first`（`nil` = 未设预算）。
- 设置 / 修改（`BudgetEditView` 保存时）：
  1. `fetch` 现有 `Budget`；
  2. 若存在 → 改其 `monthlyAmount`（**不 insert**，避免增行）；
  3. 若不存在 → `context.insert(Budget(monthlyAmount:))`（首次设置时才插入唯一一行）。
- 清除预算：`context.delete(现有 Budget)`（删掉那一行）→ 回到 `budgets.first == nil` 的空态。
- 导入备份：同样走"获取或创建"（见 6.x），不会因导入产生第二行。
- 防御：若历史数据异常出现多行（理论上不会），读取侧 `budgets.first` 取第一行、不崩；写入侧只改 / 删第一行。**不在本期做"多行清理"逻辑**（YAGNI；如需可后续单列）。

### 3.3 是否需要数据迁移 —— **不需要**

**核实结论：新增一个独立、与现有模型无任何关系（`@Relationship`）的 `@Model`，不改动任何既有模型的字段，SwiftData 轻量迁移自动加入新实体，既有 `Transaction`/`Category`/`PaymentMethod`/`Loan*` 数据不受影响、无需手写 `SchemaMigrationPlan`。** 唯一前置动作是把 `Budget.self` 登记进两处容器 schema（`ExpenseTrackerApp.swift` 与 `TestContext.swift`）——这不是"数据迁移"，是 schema 注册。

- 老用户升级：首次进新版本，`Budget` 表为空 → `budgets.first == nil` → 预算卡显示空态。符合"未设预算"。
- `Budget` 与 `Transaction` **无关系**：删交易 / 删分类 / 删支付方式都不触及 `Budget`；反之删预算也不影响任何交易。与 crud-completion 的 `.nullify` 删除策略**互不相干**（预算不挂在分类上，故 PRD 里"删分类要清理其预算"在单一总预算下天然不存在）。

## 4. 关键算法 / 公式

### 4.1 `BudgetStatus`（纯逻辑，可单测）

把"由预算金额 + 已用算出展示所需的一切"收敛到一个无依赖结构体，供 `BudgetCard` 渲染、供 XCTest 直接验证：

```
struct BudgetStatus {
    let budget: Decimal      // 总预算（> 0）
    let used: Decimal        // 本月已用（= MonthlySummary.dailySpending，≥ 0）

    var remaining: Decimal { budget - used }          // 可为负
    var isOverspent: Bool { used > budget }            // 严格大于才算超支
    var overspentAmount: Decimal { isOverspent ? used - budget : 0 }

    /// 进度比例（0…1），用于进度条；超支夹到 1（条满）。budget<=0 视为 0 防除零。
    var fraction: Double { /* used/budget，clamp [0,1]，Decimal→Double 仅用于条长度，不参与金额 */ }

    /// 是否到/超 100%（变红阈值）。等于也变红：used >= budget。
    var atOrOverLimit: Bool { used >= budget }
}
```

- **超支判定**：`used > budget`（PRD FR：已用 > 预算即超支）。
- **变红阈值**：`used >= budget`（PRD「到/超 100% 变红」——恰好用满即变红）。注意与 `isOverspent`（严格 >）的区别：用满 100%（`used == budget`）变红但"剩 ¥0"、未超支；超过才显示"超支 ¥X"。
- **文案**（供卡片副标题）：
  - `used > budget` → 「超支 \(Money.string(overspentAmount))」（红）。
  - `used <= budget` → 「剩 \(Money.string(remaining))」（`used == budget` 时剩 ¥0.00，红；否则常规色）。
- **进度条长度**用 `fraction`（`Double`）——这是**唯一允许 `Double` 出现的地方**，且仅用于 UI 条长度（0…1），**不参与任何金额运算**（金额全程 `Decimal`）。设计上 `BudgetStatus` 的金额属性（`remaining`/`overspentAmount`）一律 `Decimal`。

### 4.2 "本月已用"怎么来 —— 复用 `MonthlySummary`，不新增口径

- `OverviewView` 已构造 `summary = MonthlySummary.make(month: .now, transactions:, loanPayments:)`。
- **已用 `used = summary.dailySpending`**（仅支出类交易、按自然月 `isDate(equalTo:.month)` 过滤、信用卡消费只算刷卡当时一次、**不含房贷利息**）——与 PRD 第 0 节"已用口径"逐字一致。
- **不扩展 `MonthlySummary`、不新建预算汇总**：`dailySpending` 即所需，多加字段反而引入"另一处口径"的维护风险。`BudgetStatus(budget: budgets.first.monthlyAmount, used: summary.dailySpending)` 即可。
- **强调**：`expenseView`（= `dailySpending + loanInterest`）与 `cashOutflowView`（= `dailySpending + loanTotalPaid`）的定义与数值**完全不变**；预算只读取 `dailySpending` 这个已存在的中间量，不改 `MonthlySummary.swift` 一行。

### 4.3 边界条件

| 场景 | 行为 |
|---|---|
| 未设预算（`budgets.first == nil`） | 卡片空态（"未设预算，去设置"引导），不构造 `BudgetStatus`、不显示进度/数字。 |
| 预算已设、本月 0 笔支出 | `used = 0`，剩余 = 预算，进度 0%，文案「剩 ¥{预算}」。 |
| 已用恰好 = 预算 | `atOrOverLimit = true`（变红）、`isOverspent = false`、文案「剩 ¥0.00」。 |
| 已用 > 预算 | 变红、`isOverspent = true`、进度条满、文案「超支 ¥{差额}」。 |
| 自然月边界 | `used` 来自 `MonthlySummary.make(month: .now…)`，跨月后上月支出不计入，本月从该月交易重新统计（沿用现有过滤）。 |
| 删 / 改交易后 | `used` 由 `@Query` → `summary.dailySpending` 自动重算，预算卡随 SwiftUI 刷新（与概览四张卡同机制）。 |
| 设的金额 ≤ 0 / 非法 | `BudgetEditView` 用 `TransactionForm.canSave` 拦在保存前，不写库（不会出现 `budget <= 0` 的 `Budget` 行）。`fraction` 仍对 `budget<=0` 做防除零兜底。 |

### 4.4 与产品不变量的关系

| 不变量 | 本设计的处置 | 结论 |
|---|---|---|
| 信用卡不重复计 | 已用 = `dailySpending`，刷卡当时记一次的口径不变；预算不引入任何"还卡"路径。 | ✅ 不破坏 |
| 房贷本金不算支出 | 不碰 `Finance/` 房贷逻辑；已用**不含房贷利息**、更不含本金。 | ✅ 不破坏 |
| 两种口径并存且数值不变 | 只读 `dailySpending`（已存在的中间量）；`expenseView`/`cashOutflowView` 定义与数值零改动。 | ✅ 不破坏 |
| 金额一律 `Decimal` | `Budget.monthlyAmount`、`used`、`remaining`、`overspentAmount` 全 `Decimal`；`fraction` 的 `Double` 仅用于进度条长度，不参与金额。 | ✅ 守住 |
| 派生值不冗余落库 | 只落 `monthlyAmount`；剩余 / 超支 / 进度 / 文案均由 `BudgetStatus` 计算。 | ✅ 守住 |
| 无网络 / 无注册 / 无广告 / 本地优先 | 全部本地 SwiftData + 视图，无网络。 | ✅ 守住 |

## 5. UI 流

### 5.1 概览「本月预算」卡 `BudgetCard`（插在四张卡之后）

**为什么新做卡而不复用 `StatCard`**：`StatCard` 是纯展示（标题 / 大字 / 副标题），无进度条、无条件变红。预算卡需要**进度条 + 到/超 100% 变红 + 空态**两套状态。强行塞进 `StatCard` 会污染其签名。新做 `BudgetCard`、沿用 `StatCard` 的视觉容器风格（`secondarySystemBackground`、圆角 14），更清晰。

- 入参：`let budget: Budget?`、`let used: Decimal`（由 `OverviewView` 传入 `budgets.first` 与 `summary.dailySpending`）。
- **已设预算**（`budget != nil`）→ 构造 `BudgetStatus(budget: budget.monthlyAmount, used: used)`：
  - 标题「本月预算」。
  - 大字：已用 / 预算，如 `Money.string(used)` + 「/ \(Money.string(budget))」（或主显已用、次显上限，开发可定排版，保证"已用、总预算、剩余"三值都可见）。
  - 进度条（`ProgressView(value: status.fraction)` 或 `Capsule` 叠加）：未到 100% 用主色 / accent，`status.atOrOverLimit` 时 `.tint(.red)`（变红）。
  - 副标题文案：`status.isOverspent ? "超支 \(Money.string(status.overspentAmount))" : "剩 \(Money.string(status.remaining))"`，`status.atOrOverLimit` 时整体红色（含"剩 ¥0.00"）。
- **未设预算**（`budget == nil`）→ 空态：标题「本月预算」+ 副文「未设预算，点去设置」+ 一个进入 `BudgetEditView` 的引导（卡片可整体作为 `NavigationLink`，或副文按钮）。空态**不显示进度条 / 数字**，不显红。
- **安静**：卡片只做颜色 / 文案，**不弹窗、不动画打扰**。

### 5.2 「我的」Tab 设预算页 `BudgetEditView`

- 入口：`ProfileView` 第一个 `Section` 内新增一行（与分类管理 / 支付方式管理并列）：
  ```
  NavigationLink { BudgetEditView() } label: { Label("预算", systemImage: "target") }
  ```
- `BudgetEditView`（被 `ProfileView` 的 `NavigationStack` push，故自身不带 `NavigationStack`，与 `SettingsView` 适配后的约定一致）：
  - `@Environment(\.modelContext)`、`@Query private var budgets: [Budget]`。
  - `@State amountText: String`：`onAppear` 时若 `budgets.first` 存在则用 `TransactionForm.amountString(amount)` 预填，否则空。
  - `Form`：
    - 一个金额输入 `Section`：`TextField("0.00", text: $amountText).keyboardType(.decimalPad)`，前缀「¥」，风格同「记一笔」金额行。
    - footer 说明：「设一个本月总支出上限。已用按自然月统计日常消费实付（不含房贷利息），每月自动重新开始。」
    - 若已设预算，额外一个「清除预算」`Section`（destructive 按钮）→ `context.delete(budgets.first)`、清空输入。
  - 保存：toolbar `.confirmationAction` 「保存」，`disabled(!TransactionForm.canSave(amountText:))`（> 0 才可存）。点击 → 走 3.2 的"获取或创建"写回 → `dismiss()` 返回（或留在原页提示已保存，开发可定，优先 `dismiss`）。
  - 校验：金额空 / `0` / 负 / 非法 → 保存置灰，与全 App 一致。
- **最少点击**：设预算属低频配置，放第 4 Tab，不影响"记一笔要快"。记账主流程零改动。

### 5.3 不打扰记账（守 PRD Q6）

- `AddTransactionView` / `TransactionListView` **不改**：记一笔不弹窗、不拦截、不显示预算进度、不加 toast。预算反馈只在概览卡与设预算页"安静"呈现。

## 6. 测试点清单（供 developer 写白盒测试）

> 标 **[单测]** 可在 XCTest 纯逻辑 / 内存 `ModelContext` 覆盖（不依赖 UI）；**[Mac-功能]** 需 `verifier` 在模拟器功能/UI 验证；**[Mac-回归]** 为不变量回归，必测。
> 设计已把"预算计算"全部收进 `BudgetStatus`（无 SwiftData / 无 UI 依赖）+ `Budget` 的获取或创建（内存 context），故 PRD 验收的**计算类全部可纯逻辑单测**，仅"概览卡显示 / 变红 / 我的Tab 设预算"需 Mac 验。

### A. `BudgetStatus` 纯逻辑（映射 AC-6/8/11 的计算面）
- B-1 **[单测]** 预算 2000、已用 800 → `remaining == 1200`、`isOverspent == false`、`atOrOverLimit == false`、文案「剩 ¥1,200.00」。（AC-6 单一总预算等价语义）
- B-2 **[单测]** 预算 2000、已用 1100（800+300 后）→ `remaining == 900`、未超支。（AC-7 计算面）
- B-3 **[单测]** 预算 2000、已用 2200 → `isOverspent == true`、`overspentAmount == 200`、`atOrOverLimit == true`、文案「超支 ¥200.00」。（AC-8）
- B-4 **[单测]** 边界：已用 == 预算（2000/2000）→ `isOverspent == false`、`atOrOverLimit == true`（变红）、`remaining == 0`、文案「剩 ¥0.00」。
- B-5 **[单测]** 已用 0 → `remaining == 预算`、`fraction == 0`、未超支。（AC-6 的 0 笔交易边界）
- B-6 **[单测]** `fraction` 单调 / clamp：已用 0→0.0、已用=预算→1.0、已用>预算→1.0（不超过 1）；`budget<=0` 时 `fraction == 0`（防除零、不崩）。
- B-7 **[单测]** Decimal 无浮点误差：预算 `0.30`、已用 `0.10` → `remaining == Decimal(string:"0.20")`；`overspentAmount`/`remaining` 均为 `Decimal`，`Money.string` 展示无误差。

### B. `Budget` 模型与已用复用（映射 AC-2/9/10/11）
- B-8 **[单测]** 获取或创建：空库时保存预算 2000 → `Budget` 表恰好 1 行、`monthlyAmount == 2000`；再次"保存改值"为 1500 → 仍 **1 行**、值为 1500（不新增行，AC-3）。用 `TestContext.count(Budget.self,…)` 断言行数。
- B-9 **[单测]** 持久化：插入 `Budget(2000)` 后 `@Query`/`fetch` 可查到（AC-2 杀进程重开仍在 → 由持久化保证，单测以 fetch 验证写入）。
- B-10 **[单测]** 清除：删除唯一 `Budget` 后 `fetch` 为空 → 业务取 `first == nil`（空态，AC-4 等价）。
- B-11 **[单测]** 已用复用口径：构造本月 3 笔支出（含一笔有原价优惠、一笔信用卡支付）→ `used = MonthlySummary.make(.now,…).dailySpending` 等于三笔实付之和；据此 `BudgetStatus` 的 used 与之一致。（AC-6 数字与本月实付合计一致）
- B-12 **[单测]** 删 / 改交易后已用随动：本月已用 1100，删掉其中 300 那笔 → `dailySpending == 800` → `BudgetStatus.used == 800`、`remaining == 1200`（AC-9）；把某笔实付改大/改小 → used 按新额（AC-10）。
- B-13 **[单测]** 自然月边界：上月一笔支出 + 本月一笔支出 → `MonthlySummary.make(month:.now)` 的 `dailySpending` 只含本月那笔 → 预算已用不含上月（AC-11）。
- B-14 **[单测]** 房贷利息不入已用：构造本月一笔消费 + 一笔含利息的 `LoanPayment` → `used == dailySpending`（仅消费，不含利息）；同时断言 `expenseView`/`cashOutflowView` 仍各自正确（口径不被预算污染）。（AC-15 关联）

### C. 备份往返（映射 AC-17 / FR-X3）
- B-15 **[单测]** 含预算导出导入：设预算 2000 → `BackupManager.export` 的快照含 `budgetAmount == 2000` → 清空后 `restore` → `Budget` 恢复为 2000、且仍 1 行。
- B-16 **[单测]** 旧备份兼容：构造一份**无 `budgetAmount` 字段**的 JSON（模拟旧版本）→ `restore` 不抛错、不创建 `Budget`（`budgets` 为空 = 未设预算）。`budgetAmount` 用可选 `Decimal?`，缺省解码为 `nil`。
- B-17 **[单测]** 导入不产生多行：库内已有一个 `Budget`，导入带预算的备份（`restore` 先清空再恢复）→ 结束后 `Budget` 仍恰好 1 行（不叠加）。

### D. UI / 概览 / 入口（需 Mac 验证）
- B-18 **[Mac-功能]** AC-12：概览出现「本月预算」卡，显示总预算 / 已用 / 剩余 + 进度条；金额经 `Money.string` 正常显示。
- B-19 **[Mac-功能]** AC-13（必）：概览**原四张卡**（本月支出 / 本月现金流出 / 本月优惠+最省的卡 / 房贷剩余）数值与位置**保持不变**——新增预算卡不影响其值。
- B-20 **[Mac-功能]** 超支变红：把已用记到 ≥ 预算 → 预算卡进度条 + 文案变红，文案为「超支 ¥X」（>）或「剩 ¥0.00」（=）。安静、无弹窗。
- B-21 **[Mac-功能]** 空态：未设预算时概览预算卡显示友好空态 + 去设置引导，不显红、不显进度。
- B-22 **[Mac-功能]** 「我的」Tab → 「预算」→ 设 2000 保存 → 返回概览卡即时反映（`@Query` 自动刷新）；再进"预算"显示已设 2000（回显）；改 1500 各处随之；清除后回空态。
- B-23 **[Mac-功能]** 记账不打扰：记一笔导致超支后，记账流程**未被弹窗 / toast 打断**；仅概览卡安静变红（AC-8 的"未被打断"面）。
- B-24 **[Mac-回归]** AC-14：本期未引入任何"还卡"路径；信用卡消费仍只算一次、不重复进已用（静态核对 + 功能确认无新增写支出入口）。

## 7. 风险与取舍

- **R1 `Budget` 多行风险**（低）：理论上若并发 / 异常出现多行 `Budget`，读取 `first` 仍工作。**缓解**：写入只走 `BudgetEditView` 单一入口的"获取或创建"，导入走 `restore` 的"先清空（含 Budget）再创建"，正常使用不会产生第二行；B-8/B-17 守"仍 1 行"。本期不做"启动时合并多行"清理（YAGNI）。
- **R2 `fraction` 用 `Double`**（受控）：进度条长度需要 `Double`。**取舍**：`fraction` 是**唯一** `Double`，且只决定条长度（0…1），**绝不参与金额运算**；所有金额属性（`remaining`/`overspentAmount`/`monthlyAmount`/`used`）保持 `Decimal`。B-7 守金额无浮点误差。
- **R3 备份格式变更兼容**（受控）：`Snapshot` 加 `budgetAmount: Decimal?`（**可选**）→ 旧备份（无此键）解码为 `nil`，按未设预算处理、不崩（B-16）。新备份被旧版本 App 读到时旧版忽略未知键（`JSONDecoder` 默认行为），互不破坏。`version` 是否从 1 升 2 可不强制（新增可选字段向后兼容），开发可保持 `version=1`；如想显式标记可升 2，但需保证旧版仍能读新档（不删字段即可）。
- **R4 容器 schema 未登记 `Budget`**（必避）：新 `@Model` 必须同时加进 `ExpenseTrackerApp.swift` 与 `TestContext.swift` 的 `ModelContainer(for:)`，否则 App 崩 / 单测查 `Budget` 崩。已在 2.2 / S 步骤显式列出。
- **R5 误伤概览四张卡**（必避）：预算卡是**追加**，不得改 `summary.expenseView` 等的取值与 `StatCard` 调用。B-19 回归守。
- **放弃的替代方案**：
  - ① 给 `Category` 加 `monthlyBudget` 字段做分类预算——PRD Q1 明确只做单一总预算，且会改既有模型 / 引入迁移 / 牵连删分类清理，放弃。
  - ② 按"周期+月份"建预算历史记录表——PRD Q3 明确不留历史 / 不结转，过度建模，放弃。
  - ③ 扩展 `MonthlySummary` 加 `monthlyConsumption` 字段——`dailySpending` 已是同口径，新增字段制造"第二处口径"维护负担，放弃；直接读 `dailySpending`。
  - ④ 把已用 / 剩余落库——违反"派生值不冗余存储"，且每月自然月滚动会让落库值过期，放弃；运行时派生。

### 产品不变量逐条核对（第 7 节门禁）
- **信用卡不重复计**：已用 = `dailySpending`（刷卡当时一次的口径），无"还卡"路径。✅
- **房贷本金不算支出**：不碰房贷逻辑；已用不含利息、不含本金；两总口径不变。✅
- **两种口径并存**：只读已存在的 `dailySpending` 中间量，`expenseView`/`cashOutflowView` 定义与数值零改动（B-14/B-19 守）。✅
- **金额一律 `Decimal`**：模型字段与所有金额派生皆 `Decimal`；`fraction` 的 `Double` 仅用于进度条长度。✅
- **派生值不落库**：只落 `monthlyAmount`；剩余/超支/进度/文案运行时算。✅
- **无网络/无注册/无广告/本地优先**：全本地。✅

## 8. 开发任务拆解（供 `developer` 按序执行）

> 每步可独立提交、独立编译通过。建议顺序：先模型 + 纯逻辑（可单测）→ 再 UI → 再备份 → 收尾回归。

- **S1 模型 + schema 登记 + 纯逻辑（可全单测）**
  - 新建 `Models/Budget.swift`（`@Model Budget { monthlyAmount: Decimal }`）。
  - `ExpenseTrackerApp.swift` 与 `Tests/TestContext.swift` 的 `ModelContainer(for:)` 追加 `Budget.self`。
  - 新建 `Finance/BudgetStatus.swift`（`remaining`/`isOverspent`/`overspentAmount`/`fraction`/`atOrOverLimit` + 文案；`fraction` 防除零）。
  - 写白盒测试 `Tests/BudgetStatusTests.swift`：B-1~B-7。
  - 写白盒测试 `Tests/BudgetModelTests.swift`（先覆盖模型部分）：B-8、B-9、B-10、B-11、B-12、B-13、B-14。
  - 自测：单测全绿；无 UI 改动。

- **S2 「我的」Tab 设预算页**
  - 新建 `Views/Settings/BudgetEditView.swift`（金额输入复用 `TransactionForm`，获取或创建写回，清除按钮，回显预填）。
  - `ProfileView` 第一个 Section 加"预算" `NavigationLink`。
  - 自测：B-22 的设 / 改 / 清除 / 回显（Mac-功能）。

- **S3 概览预算卡**
  - 新建 `Views/Overview/BudgetCard.swift`（进度条 + 变红 + 空态，入参 `budget: Budget?`、`used: Decimal`）。
  - `OverviewView` 加 `@Query budgets`，四张卡后插入 `BudgetCard(budget: budgets.first, used: summary.dailySpending)`。
  - 自测：B-18、B-19（四张卡不变，必）、B-20（超支红）、B-21（空态）、B-23（不打扰）。

- **S4 备份兼容**
  - `BackupManager.Snapshot` 加 `budgetAmount: Decimal?`；`export` 写入 `budgets.first?.monthlyAmount`；`restore` 在清空阶段一并 `delete` 现有 `Budget`，恢复阶段 `budgetAmount` 非 `nil` 时 `insert(Budget(...))`。
  - 写白盒测试（追加进 `BudgetModelTests.swift`）：B-15、B-16、B-17。
  - 自测：往返恢复、旧备份不崩、不产生多行。

- **S5 回归收尾**
  - 走查 B-19（四张卡数值不变）、B-14（两口径不被污染）、B-24（信用卡不重复）等不变量回归。
  - 交 `reviewer` 检视 → `verifier` Mac 端编译 / 单测 / 功能 / 性能。

---

### 给调用者的提示
设计要点：
- **模型落点**：新建独立 `@Model Budget { monthlyAmount: Decimal }`，全库一行，"获取或创建"由 `BudgetEditView` 单一写入入口保证；**无需数据迁移**（仅需把 `Budget.self` 登记进 `ExpenseTrackerApp.swift` 与 `TestContext.swift` 两处容器 schema）。
- **已用口径复用**：直接取 `MonthlySummary.make(...).dailySpending`（仅支出、自然月、信用卡不重复、不含房贷利息），**不改 `MonthlySummary` 一行**、不新增第二处口径；两个总口径数值零变动。
- **预算计算做成纯逻辑** `BudgetStatus`（无 SwiftData/UI 依赖），PRD 验收的计算面全部可单测；仅概览卡显示 / 变红 / 我的Tab 设预算需 Mac 验证。
- **拆成 5 步**（S1 模型+纯逻辑 → S2 设预算页 → S3 概览卡 → S4 备份 → S5 回归）。

按流程门禁，**需人确认本设计后**方可进入 `developer` 开发阶段。
