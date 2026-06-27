import SwiftUI
import SwiftData

/// 交易只读详情页：金额大字 + 字段罗列 + 右上「编辑」 + 底部「删除」（含二次确认）。
/// 不展示「记录时间」（已确认去掉，「日期」已覆盖）。
struct TransactionDetailView: View {
    let transaction: Transaction

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingEdit = false
    @State private var confirmingDelete = false

    private var signedAmount: String {
        let prefix = transaction.kind == .income ? "+" : "-"
        return prefix + Money.string(transaction.actualAmount)
    }

    var body: some View {
        List {
            Section {
                Text(signedAmount)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(transaction.kind == .income ? .green : .primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
            }

            Section {
                row("收支类型", value: transaction.kind.label)

                if let original = transaction.originalAmount {
                    row("原价", value: Money.string(original))
                    if transaction.discount > 0 {
                        row("省下", value: Money.string(transaction.discount), valueColor: .orange)
                    }
                }

                HStack {
                    Text("分类")
                    Spacer()
                    if let category = transaction.category {
                        Label(category.name, systemImage: category.icon)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("未分类").foregroundStyle(.secondary)
                    }
                }

                row("支付方式", value: transaction.paymentMethod?.name ?? "未指定")

                row("日期", value: dateText)

                if !transaction.note.isEmpty {
                    row("备注", value: transaction.note)
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("删除", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("交易详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddTransactionView(editing: transaction)
        }
        .confirmationDialog("删除这笔账？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                context.delete(transaction)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复。")
        }
    }

    private var dateText: String {
        transaction.date.formatted(.dateTime.year().month().day())
    }

    private func row(_ title: String, value: String, valueColor: Color = .secondary) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(valueColor)
        }
    }
}
