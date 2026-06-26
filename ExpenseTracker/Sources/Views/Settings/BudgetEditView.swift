import SwiftUI
import SwiftData

/// 「我的」Tab 下的设 / 改 / 清除本月总预算页。
///
/// 由 `ProfileView` 的 `NavigationStack` 以 `NavigationLink` push 进入，故自身不带 `NavigationStack`。
/// 金额输入复用 `TransactionForm` 的解析 / 校验 / 往返（全 `Decimal`、> 0 才可存），与「记一笔」同款。
/// 保存走「获取或创建」：fetch 有则改其 `monthlyAmount`（不 insert）、无则插唯一一行 —— 保证全库一行。
struct BudgetEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var budgets: [Budget]

    @State private var amountText: String = ""

    @FocusState private var amountFocused: Bool

    private var existing: Budget? { budgets.first }

    private var canSave: Bool { TransactionForm.canSave(amountText: amountText) }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("¥").foregroundStyle(.secondary)
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 34, weight: .semibold))
                        .focused($amountFocused)
                        .accessibilityIdentifier("budget-amount-field")
                }
            } footer: {
                Text("设一个本月总支出上限。已用按自然月统计日常消费实付（不含房贷利息），每月自动重新开始。")
            }

            if existing != nil {
                Section {
                    Button(role: .destructive) {
                        clearBudget()
                    } label: {
                        Label("清除预算", systemImage: "trash")
                    }
                    .accessibilityIdentifier("clear-budget-button")
                }
            }
        }
        .navigationTitle("预算")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save).disabled(!canSave)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { amountFocused = false }
            }
        }
        .onAppear(perform: prefill)
    }

    /// 进入时若已设预算则回显，否则留空。
    private func prefill() {
        if let b = existing, amountText.isEmpty {
            amountText = TransactionForm.amountString(b.monthlyAmount)
        }
    }

    /// 「获取或创建」写回：有则改、无则插唯一一行。> 0 校验在 `canSave` / 此处双保险。
    private func save() {
        guard let amount = TransactionForm.parseAmount(amountText), amount > 0 else { return }
        if let b = existing {
            b.monthlyAmount = amount
        } else {
            context.insert(Budget(monthlyAmount: amount))
        }
        try? context.save()   // 显式落盘：保证即时持久化，不依赖自动保存时机
        dismiss()
    }

    /// 清除预算：删第一行 → 回到空态；清空输入。
    private func clearBudget() {
        if let b = existing {
            context.delete(b)
        }
        amountText = ""
        try? context.save()   // 显式落盘：删除即时持久化
        dismiss()
    }
}
