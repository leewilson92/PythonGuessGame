import SwiftUI
import SwiftData

/// 添加房贷的一部分（公积金贷 / 商贷）。填：剩余本金、年利率、剩余期数。
struct AddLoanTrancheView: View {
    let loan: Loan
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = "商贷"
    @State private var principalText: String = ""
    @State private var rateText: String = ""        // 按百分比输入，如 3.1
    @State private var termsText: String = ""

    private var principal: Decimal? { Decimal(string: principalText) }
    private var rate: Decimal? {
        guard let pct = Decimal(string: rateText) else { return nil }
        return pct / 100
    }
    private var terms: Int? { Int(termsText) }

    private var canSave: Bool {
        (principal ?? 0) > 0 && (rate ?? 0) >= 0 && (terms ?? 0) > 0 && !name.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    Picker("快速选择", selection: $name) {
                        Text("公积金贷").tag("公积金贷")
                        Text("商贷").tag("商贷")
                    }
                    .pickerStyle(.segmented)
                    TextField("名称", text: $name)
                }

                Section("贷款条件") {
                    labeledField("剩余本金", text: $principalText, suffix: "元")
                    labeledField("年利率", text: $rateText, suffix: "%")
                    labeledField("剩余期数", text: $termsText, suffix: "期")
                }

                if canSave, let p = principal, let r = rate, let n = terms {
                    Section("预估") {
                        let split = MortgageCalculator.nextSplit(principal: p, annualRate: r, remainingTerms: n)
                        Text("下期月供约 \(Money.string(split.total))")
                        Text("其中本金 \(Money.string(split.principal))，利息 \(Money.string(split.interest))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("添加贷款部分")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, suffix: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(suffix).foregroundStyle(.secondary)
        }
    }

    private func save() {
        guard let principal, let rate, let terms else { return }
        let tranche = LoanTranche(name: name, openingPrincipal: principal, annualRate: rate, remainingTerms: terms)
        tranche.loan = loan
        context.insert(tranche)
        dismiss()
    }
}
