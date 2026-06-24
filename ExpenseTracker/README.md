# 记账 · 极简个人财务 App（iOS）

一个只属于你的、打开就用、**无注册 / 无广告 / 无网络**的极简记账 App。
记花销、看银行卡优惠、管房贷负债。原生 SwiftUI + SwiftData，数据全在本机。

> 完整产品设计见仓库根目录计划文档。本目录是第一版（MVP）源码。

## 功能（v1）

- **记一笔**：实付金额、可选原价（自动算优惠）、分类、支付方式、日期、备注。
- **优惠**：逐笔记原价/优惠/实付；概览显示本月省了多少、**哪张卡最省**。
- **房贷（混合贷）**：拆成「公积金贷 + 商贷」等多部分，各填条件（剩余本金/年利率/剩余期数），
  每月点「确认本月还款」自动按**等额本息**拆本金利息、自动减负债。支持**提前还款**和**调整利率**并重算。
- **两种财务视角**：本月支出（消费+房贷利息） vs 本月现金流出（含房贷全额还款）。
- **数据备份**：设置里一键导出/导入 JSON 备份，防换机丢数据。

> 注：信用卡消费在刷卡当时记为支出；之后“还信用卡”不另记，避免重复计。

## 在 Mac 上构建运行

需要 **macOS + Xcode 15+**（iOS 17 SDK）。本项目用 [XcodeGen](https://github.com/yonsm/XcodeGen) 生成工程。

```bash
# 1. 安装 XcodeGen（只需一次）
brew install xcodegen

# 2. 在本目录生成 Xcode 工程
cd ExpenseTracker
xcodegen generate

# 3. 打开
open ExpenseTracker.xcodeproj
```

然后在 Xcode 里选一个模拟器（或你的 iPhone），按 ⌘R 运行。

> 不想用 XcodeGen 也行：在 Xcode 新建一个 iOS App（SwiftUI + SwiftData），
> 把 `Sources/` 下所有 `.swift` 拖进去即可。

## 跑测试

房贷计算有单元测试：

```bash
xcodegen generate
xcodebuild test -scheme ExpenseTracker -destination 'platform=iOS Simulator,name=iPhone 15'
```

或在 Xcode 里按 ⌘U。

## 目录结构

```
ExpenseTracker/
  project.yml                 # XcodeGen 配置
  Sources/
    ExpenseTrackerApp.swift    # @main，初始化 SwiftData 容器 + 首启种子
    Models/                    # SwiftData @Model：Transaction/Category/PaymentMethod/Loan...
    Finance/                   # 等额本息计算、房贷动作、月度汇总、格式化
    Seed/                      # 默认分类 + 支付方式
    Backup/                    # 导出/导入备份
    Views/                     # 三个 Tab + 各表单
  Tests/
    MortgageCalculatorTests.swift
```

## 上架 App Store 前要做的（路线图，非本版）

- 注册 **Apple 开发者账号**（99 美元/年），设好正式 Bundle ID 与签名。
- 加 App 图标、启动页、截图。
- 加隐私清单（强调“数据不离开设备”）。
- 建议先补上：iCloud 同步、Face ID 锁、图标/品牌。

## 下一步路线图

- **阶段 2**：资产/账户余额 + 收入端 → 净身价/净现金流；iCloud（CloudKit）同步；图表；预算。
- **阶段 3**：自动记账探索 —— Siri 快捷指令、分享扩展、支付宝/微信账单 CSV 导入
  （注意：iOS 不允许读取支付通知，做不到后台全自动）。
- **阶段 4**：Face ID 锁 + 上架打磨。
