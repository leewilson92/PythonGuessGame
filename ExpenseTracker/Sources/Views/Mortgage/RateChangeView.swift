import SwiftUI
import SwiftData

/// 调整利率：商贷 LPR 浮动时改年利率，后续月供按新利率重算。
struct RateChangeView: View {
    let tranche: LoanTranche
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var rateText: String = ""
    @State private var date: Date = .now

    private var newRate: Decimal? {
        guard let pct = Decimal(string: rateText) else { return nil }
        return pct / 100
    }
    private var canSave: Bool { (newRate ?? -1) >= 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("当前年利率 \(Money.percent(tranche.annualRate))")
                        .foregroundStyle(.secondary)
                }
                Section("新年利率") {
                    HStack {
                        TextField("如 3.1", text: $rateText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("%").foregroundStyle(.secondary)
                    }
                    DatePicker("生效日期", selection: $date, displayedComponents: .date)
                }
                if let newRate {
                    Section("调整后") {
                        let split = MortgageCalculator.nextSplit(principal: tranche.currentPrincipal, annualRate: newRate, remainingTerms: tranche.remainingTerms)
                        Text("下期月供约 \(Money.string(split.total))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("调整利率")
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
        guard let newRate else { return }
        LoanService(context: context).changeRate(to: newRate, for: tranche, date: date)
        dismiss()
    }
}
