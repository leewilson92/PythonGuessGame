import SwiftUI
import SwiftData

/// 账目列表，按日期分组。右上「+」记一笔。
struct TransactionListView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showingAdd = false

    private var grouped: [(day: Date, items: [Transaction])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: transactions) { cal.startOfDay(for: $0.date) }
        return dict.keys.sorted(by: >).map { ($0, dict[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "还没有账目",
                        systemImage: "tray",
                        description: Text("点右上角「+」记第一笔")
                    )
                } else {
                    List {
                        ForEach(grouped, id: \.day) { group in
                            Section(header: dayHeader(group.day, items: group.items)) {
                                ForEach(group.items) { tx in
                                    NavigationLink {
                                        TransactionDetailView(transaction: tx)
                                    } label: {
                                        TransactionRow(tx: tx)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("记账")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddTransactionView()
            }
        }
    }

    private func dayHeader(_ day: Date, items: [Transaction]) -> some View {
        let spent = items.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.actualAmount }
        return HStack {
            Text(day, format: .dateTime.month().day().weekday())
            Spacer()
            Text("支出 \(Money.string(spent))")
                .foregroundStyle(.secondary)
        }
    }
}

private struct TransactionRow: View {
    let tx: Transaction
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tx.category?.icon ?? "circle")
                .frame(width: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.category?.name ?? "未分类")
                if !tx.note.isEmpty {
                    Text(tx.note).font(.caption).foregroundStyle(.secondary)
                }
                if let pm = tx.paymentMethod {
                    Text(pm.name).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(signedAmount)
                    .foregroundStyle(tx.kind == .income ? .green : .primary)
                if tx.discount > 0 {
                    Text("省 \(Money.string(tx.discount))")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                context.delete(tx)
            } label: { Label("删除", systemImage: "trash") }
        }
    }

    private var signedAmount: String {
        let prefix = tx.kind == .income ? "+" : "-"
        return prefix + Money.string(tx.actualAmount)
    }
}
