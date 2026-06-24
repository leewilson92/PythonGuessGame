# CLAUDE.md

极简个人财务 App（自用为主，目标上架 App Store）。

## 技术栈
- 原生 **Swift + SwiftUI + SwiftData**，iOS 17+。
- 工程用 **XcodeGen**：`cd ExpenseTracker && xcodegen generate` 生成 `.xcodeproj`。
- 源码在 `ExpenseTracker/Sources/`（`Models` / `Finance` / `Views` / `Seed` / `Backup`），测试在 `ExpenseTracker/Tests/`。
- 本地优先存储，**无网络、无注册、无广告**。

## 开发流程（必读）
本项目所有功能走 `DEV_PROCESS.md` 的多-agent 流水线：
**architect（设计）→ developer（开发+白盒测试）→ reviewer（检视）→ verifier（Mac 编译/功能/性能）→ 提交**。
子agent 定义在 `.claude/agents/`。设计文档放 `docs/design/`（模板见 `docs/design/TEMPLATE.md`）。
> 编译/功能/性能测试只能在 macOS + Xcode 上跑。

## 产品不变量（改动时务必守住）
- **信用卡不重复计**：刷卡当时记为支出；"还信用卡"不另记支出（只是现金流事件）。
- **房贷本金不算支出**：还款里只有利息进"本月支出"，本金只减负债。
- **两种口径并存**：本月支出 = 消费实付 + 房贷利息；本月现金流出 = 消费实付 + 房贷全额还款。两者都要对。
- **金额一律 `Decimal`**，禁止 `Double` 参与金额运算。
- **派生值计算得出**（优惠 = 原价 − 实付；负债剩余 = 期初 − Σ本金），不冗余落库。

## 常用命令（Mac）
```bash
cd ExpenseTracker
xcodegen generate
xcodebuild -project ExpenseTracker.xcodeproj -scheme ExpenseTracker \
  -destination 'platform=iOS Simulator,name=iPhone 15' build   # 编译
xcodebuild test -project ExpenseTracker.xcodeproj -scheme ExpenseTracker \
  -destination 'platform=iOS Simulator,name=iPhone 15'          # 单测
open ExpenseTracker.xcodeproj                                    # Xcode 里 Cmd+R / Cmd+U
```

完整产品方案见仓库内设计文档与 `ExpenseTracker/README.md`。
