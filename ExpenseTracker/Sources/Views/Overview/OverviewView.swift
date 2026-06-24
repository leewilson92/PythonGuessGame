import SwiftUI
import SwiftData

/// 概览：本月支出（消费+利息）、本月现金流出（含房贷全额）、本月优惠 + 最省的卡、房贷剩余。
struct OverviewView: View {
    @Query private var transactions: [Transaction]
    @Query private var loanPayments: [LoanPayment]
    @Query private var loans: [Loan]

    @State private var showingSettings = false

    private var summary: MonthlySummary {
        MonthlySummary.make(month: .now, transactions: transactions, loanPayments: loanPayments)
    }

    private var loanRemaining: Decimal {
        loans.reduce(0) { $0 + $1.totalRemaining }
    }
    private var loanPaidPrincipal: Decimal {
        loans.reduce(0) { $0 + $1.totalPaidPrincipal }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        StatCard(title: "本月支出", subtitle: "消费 + 房贷利息",
                                 value: Money.string(summary.expenseView), tint: .red)
                        StatCard(title: "本月现金流出", subtitle: "含房贷全额还款",
                                 value: Money.string(summary.cashOutflowView), tint: .blue)
                    }

                    StatCard(title: "本月优惠合计",
                             subtitle: summary.topSavingMethodName.map { "最省：\($0)（\(Money.string(summary.topSavingAmount))）" } ?? "记账时填原价即可统计",
                             value: Money.string(summary.discountTotal), tint: .orange)

                    StatCard(title: "房贷剩余",
                             subtitle: "已还本金 \(Money.string(loanPaidPrincipal))",
                             value: Money.string(loanRemaining), tint: .green)

                    Text("「本月支出」按消耗口径（只算利息），「现金流出」按现金口径（含本金）。两者互不矛盾。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding()
            }
            .navigationTitle("概览")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }
}

private struct StatCard: View {
    let title: String
    let subtitle: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.system(size: 26, weight: .bold)).foregroundStyle(tint)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
