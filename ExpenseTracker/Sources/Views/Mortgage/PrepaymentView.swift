import SwiftUI
import SwiftData

/// 提前还款：减少剩余本金，期数不变 → 后续月供自动变小。
struct PrepaymentView: View {
    let tranche: LoanTranche
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String = ""
    @State private var date: Date = .now

    private var amount: Decimal? { Decimal(string: amountText) }
    private var canSave: Bool {
        guard let amount else { return false }
        return amount > 0 && amount <= tranche.currentPrincipal
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("当前剩余本金 \(Money.string(tranche.currentPrincipal))")
                        .foregroundStyle(.secondary)
                }
                Section("提前还款") {
                    HStack {
                        Text("金额")
                        Spacer()
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("元").foregroundStyle(.secondary)
                    }
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }
                if let amount, amount > 0, amount <= tranche.currentPrincipal {
                    Section("还后") {
                        let after = tranche.currentPrincipal - amount
                        Text("剩余本金 \(Money.string(after))")
                        let split = MortgageCalculator.nextSplit(principal: after, annualRate: tranche.annualRate, remainingTerms: tranche.remainingTerms)
                        Text("下期月供约 \(Money.string(split.total))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("提前还款")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard let amount else { return }
        LoanService(context: context).prepay(amount, for: tranche, date: date)
        dismiss()
    }
}
