# PRD 总览与需求管理

本目录存放各功能的产品需求文档（PRD），由 `product-manager` 子agent 维护。
产品北极星与整体方案见 [`../PRODUCT_PLAN.md`](../PRODUCT_PLAN.md)。

## 文档先行（流程铁律）

**任何新功能或功能改动，先更新文档，再动代码：**

```
PRD（本目录 docs/prd/）→ 设计文档（docs/design/）→ 才进开发
```

每次功能新增或修改，对应的 PRD 与设计文档必须**同步更新**（含验收标准的变化）。代码改了文档没改，视为未完成。

## 在流水线中的位置

```
用户提需求 → ① product-manager 出 PRD →【人确认】
           → ② architect 出设计    →【人确认】
           → ③ developer 开发 + 白盒测试
           → ④ reviewer 检视       → developer 修复
           → ⑤ verifier Mac 端验证
           → ⑥ 全绿 → commit / push
```

## PRD 列表与状态

| 功能 | PRD | 状态 | 设计 | 备注 |
|---|---|---|---|---|
| 补全 CRUD（交易/分类/支付方式） | [crud-completion.md](crud-completion.md) | **已确认** | 待 architect | 交易"改"+详情页；分类/支付方式增删改+排序；新增「我的」Tab 收纳管理入口。6 个开放问题已全部拍板（删除=置未分类/.nullify）。 |
| 月度预算 | [monthly-budget.md](monthly-budget.md) | **已确认** | 待 architect | 阶段2 首个增量。**单一总预算**（本期不做分类预算）+ 每月自动沿用不结转 + 只支出口径；概览加预算卡、「我的」Tab 设、超支安静变红、房贷利息不计入。7 个开放问题已全部拍板，模型很轻。 |

## 需求待办 backlog（已识别、未开 PRD）

> 用户作为使用者随时往这里加；开 PRD 时从这里取。

- ~~**交易"改" + 详情页**：编辑已有交易，以及点进单笔的详情页。~~ → 已开 PRD [crud-completion.md](crud-completion.md)（**已确认**），范围扩展到**交易 / 分类 / 支付方式三类对象的 CRUD 补全**。（用户 2026-06-25 提出）
