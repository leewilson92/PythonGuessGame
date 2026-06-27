# 开发规范（多-agent 流水线）

本项目（极简个人财务 App，iOS / Swift + SwiftUI + SwiftData）每个功能/较大改动都走同一条流水线，
由 4 个专门子agent 分工。子agent 定义在 `.claude/agents/`，在本仓库内打开 Claude Code 即自动可用。

> ⚠️ 编译、功能测试、性能测试**只能在 macOS + Xcode** 上跑（`verifier` 环节）。
> 设计、开发、写测试、代码检视在任意环境可做；建议在 **Mac 本地** 跑完整流水线。

## 流水线

```
① 产品方案 product-manager → 产出/更新 docs/prd/<feature>.md（PRD） →【人确认】门禁
② 架构设计 architect   →  产出 docs/design/<feature>.md     →【人确认】门禁
③ 开发+白盒测试 developer →  实现 + XCTest 单测
④ 代码检视 reviewer    →  findings 清单  →  developer 修复（循环至无 🔴 阻断项）
⑤ Mac 端验证 verifier  →  生成工程 + 编译 + 单测 + 功能 + 性能  →  报告
⑥ 全绿               →  commit / 更新 PR
```

> 用户作为 App 使用者用自然语言提需求，**先到 product-manager 出 PRD**；技术设计、开发、检视、验证依次在后。**文档先行**：功能改了，PRD 与设计文档同步更新。

## 5 个角色

| 角色 | 子agent | 职责 | 产出 |
|---|---|---|---|
| 产品经理 | `product-manager` | 把用户需求转成产品方案、管理需求、出/更新 PRD | `docs/prd/<feature>.md` |
| 架构师 | `architect` | 开发前分析需求、复用现有模式、出设计文档 | `docs/design/<feature>.md` |
| 开发（含白盒测试） | `developer` | 按设计实现 + 同步写 XCTest；修复检视阻断项 | 代码 + `ExpenseTracker/Tests/` |
| 代码检视 | `reviewer` | 独立静态检视，只报告不改 | 分级 findings 清单 |
| Mac 端验证 | `verifier` | 编译/单测/功能/性能（仅 Mac） | 验证报告 |

合并自用户最初的 6 步：开发与"写白盒测试"合并（TDD 同上下文）；"功能测试 + 性能测试"合并为 Mac 端验证；代码检视保持独立。后又在最前增设 `product-manager`，把用户需求先沉淀成 PRD（文档先行）。

## 门禁（gates）

1. **无 PRD 不设计**：`product-manager` 的 PRD 经人确认后才进 `architect`。
2. **无设计文档不开发**：`architect` 文档经人确认后才进 `developer`。
3. **有阻断项不进验证**：`reviewer` 列出 🔴 必须先由 `developer` 修复。
4. **不全绿不合并**：`verifier` 编译/单测/功能必须通过才提交或更新 PR。
5. **文档先行**：每次新增或修改功能，先更新 PRD 与设计文档，再动代码。

## 如何调用

在本仓库内的 Claude Code 中，按阶段把任务交给对应子agent，例如：
- "我要加 X 功能" / "用 product-manager 把 X 写成 PRD" → 评审 `docs/prd/X.md` → 确认。
- "用 architect 按 docs/prd/X.md 设计 X" → 评审 `docs/design/X.md` → 确认。
- "用 developer 按 docs/design/X.md 实现并写测试"。
- "用 reviewer 检视当前改动"。
- "用 verifier 在 Mac 上编译并跑全部测试"。

## 必须守住的产品不变量

- 信用卡消费刷卡当时记支出；"还信用卡"不另记支出（不重复计）。
- 房贷还款里只有**利息**算"本月支出"，本金只减负债。
- 两种口径并存且各自正确：本月支出（消费实付+房贷利息）/ 本月现金流出（消费实付+房贷全额还款）。
- 金额一律 `Decimal`；派生值（优惠、负债剩余）计算得出不落库。
- 无网络、无注册、无广告；本地优先。

完整产品背景见仓库内总体设计方案与 `ExpenseTracker/README.md`。
