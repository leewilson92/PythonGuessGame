import SwiftUI

/// 概览「本月预算」卡：总预算 / 已用 / 剩余 + 进度条；到 / 超 100% 安静变红；未设预算显示友好空态。
///
/// 入参 `budget`（= `budgets.first`，`nil` 即未设预算）与 `used`（= `summary.dailySpending`）。
/// 卡片只做颜色 / 文案，不弹窗、不动画打扰（守 PRD「不打扰」）。
/// 视觉容器风格（`secondarySystemBackground`、圆角 14）与概览四张 `StatCard` 一致。
struct BudgetCard: View {
    let budget: Budget?
    let used: Decimal

    var body: some View {
        if let budget {
            setView(status: BudgetStatus(budget: budget.monthlyAmount, used: used))
        } else {
            emptyView
        }
    }

    // MARK: - 已设预算

    private func setView(status: BudgetStatus) -> some View {
        let accent: Color = status.atOrOverLimit ? .red : .accentColor
        return VStack(alignment: .leading, spacing: 8) {
            Text("本月预算").font(.subheadline).foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Money.string(status.used))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(accent)
                Text("/ \(Money.string(status.budget))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: status.fraction)
                .tint(accent)

            Text(status.statusText)
                .font(.caption2)
                .foregroundStyle(status.atOrOverLimit ? .red : .secondary)
                .accessibilityIdentifier("budget-status-text")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 未设预算空态

    private var emptyView: some View {
        NavigationLink {
            BudgetEditView()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("本月预算").font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    Text("未设预算，点去设置")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("budget-card-empty")
    }
}
