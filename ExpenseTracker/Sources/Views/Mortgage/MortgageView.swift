import SwiftUI
import SwiftData

/// 房贷页：混合贷拆成多部分，每部分可确认月供 / 提前还款 / 改利率。
struct MortgageView: View {
    @Environment(\.modelContext) private var context
    @Query private var loans: [Loan]
    @Query(sort: \LoanPayment.date, order: .reverse) private var payments: [LoanPayment]

    @State private var showingAddTranche = false

    private var loan: Loan? { loans.first }

    var body: some View {
        NavigationStack {
            Group {
                if let loan, !loan.tranches.isEmpty {
                    loanContent(loan)
                } else {
                    ContentUnavailableView {
                        Label("还没有房贷", systemImage: "house")
                    } description: {
                        Text("把你的房贷加进来。混合贷可分别添加「公积金贷」和「商贷」两部分。")
                    } actions: {
                        Button("添加房贷") { showingAddTranche = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("房贷")
            .toolbar {
                if loan?.tranches.isEmpty == false {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingAddTranche = true } label: { Image(systemName: "plus") }
                    }
                }
            }
            .sheet(isPresented: $showingAddTranche) {
                AddLoanTrancheView(loan: loanOrCreate())
            }
        }
    }

    private func loanOrCreate() -> Loan {
        if let loan { return loan }
        let new = Loan()
        context.insert(new)
        return new
    }

    private func loanContent(_ loan: Loan) -> some View {
        List {
            Section {
                VStack(spacing: 6) {
                    Text("负债总剩余").font(.subheadline).foregroundStyle(.secondary)
                    Text(Money.string(loan.totalRemaining))
                        .font(.system(size: 32, weight: .bold))
                    Text("已还本金 \(Money.string(loan.totalPaidPrincipal))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            ForEach(loan.tranches) { tranche in
                Section(tranche.name) {
                    TrancheCard(tranche: tranche)
                }
            }

            if !payments.isEmpty {
                Section("还款记录") {
                    ForEach(payments) { p in
                        PaymentRow(payment: p)
                    }
                }
            }
        }
    }
}

private struct TrancheCard: View {
    @Bindable var tranche: LoanTranche
    @Environment(\.modelContext) private var context

    @State private var showPrepay = false
    @State private var showRate = false

    private var nextSplit: (total: Decimal, principal: Decimal, interest: Decimal) {
        MortgageCalculator.nextSplit(
            principal: tranche.currentPrincipal,
            annualRate: tranche.annualRate,
            remainingTerms: tranche.remainingTerms
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow("剩余本金", Money.string(tranche.currentPrincipal))
            infoRow("年利率", Money.percent(tranche.annualRate))
            infoRow("剩余期数", "\(tranche.remainingTerms) 期")
            if tranche.remainingTerms > 0 {
                infoRow("下期月供", Money.string(nextSplit.total))
                Text("其中本金 \(Money.string(nextSplit.principal))，利息 \(Money.string(nextSplit.interest))")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    LoanService(context: context).confirmMonthlyPayment(for: tranche)
                } label: {
                    Text("确认本月还款")
                }
                .buttonStyle(.borderedProminent)
                .disabled(tranche.remainingTerms == 0 || tranche.currentPrincipal == 0)

                Spacer()

                Menu {
                    Button("提前还款") { showPrepay = true }
                    Button("调整利率") { showRate = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showPrepay) { PrepaymentView(tranche: tranche) }
        .sheet(isPresented: $showRate) { RateChangeView(tranche: tranche) }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }
}

private struct PaymentRow: View {
    let payment: LoanPayment
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(payment.tranche?.name ?? "房贷")
                Text(payment.date, format: .dateTime.year().month().day())
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(Money.string(payment.totalAmount))
                Text("本金 \(Money.string(payment.principal)) · 息 \(Money.string(payment.interest))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
