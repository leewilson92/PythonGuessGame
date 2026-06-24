import SwiftUI
import SwiftData

/// 记一笔。金额键盘优先，默认值齐全（今天 / 上次用的支付方式），主打快。
struct AddTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortIndex) private var categories: [Category]
    @Query(sort: \PaymentMethod.sortIndex) private var methods: [PaymentMethod]
    @Query(sort: \Transaction.date, order: .reverse) private var recentTx: [Transaction]

    @State private var kind: TransactionKind = .expense
    @State private var amountText: String = ""
    @State private var originalText: String = ""
    @State private var showOriginal = false
    @State private var selectedCategory: Category?
    @State private var selectedMethod: PaymentMethod?
    @State private var date: Date = .now
    @State private var note: String = ""

    @FocusState private var amountFocused: Bool

    private var filteredCategories: [Category] {
        categories.filter { $0.kind == kind }
    }

    private var amount: Decimal? { Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) }
    private var original: Decimal? { showOriginal ? Decimal(string: originalText) : nil }

    private var canSave: Bool {
        guard let amount, amount > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("类型", selection: $kind) {
                        ForEach(TransactionKind.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, _ in
                        if selectedCategory?.kind != kind { selectedCategory = filteredCategories.first }
                    }

                    HStack {
                        Text("¥").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 34, weight: .semibold))
                            .focused($amountFocused)
                    }
                }

                Section("分类") {
                    categoryGrid
                }

                Section {
                    Toggle("有优惠（记原价）", isOn: $showOriginal.animation())
                    if showOriginal {
                        HStack {
                            Text("原价")
                            Spacer()
                            TextField("原价", text: $originalText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        if let d = discountPreview, d > 0 {
                            Text("省下 \(Money.string(d))")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("支付方式") {
                    Picker("支付方式", selection: $selectedMethod) {
                        Text("未指定").tag(PaymentMethod?.none)
                        ForEach(methods) { m in
                            Text(m.name).tag(PaymentMethod?.some(m))
                        }
                    }
                }

                Section {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    TextField("备注", text: $note)
                }
            }
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: applyDefaults)
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            ForEach(filteredCategories) { c in
                Button {
                    selectedCategory = c
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: c.icon)
                            .font(.title3)
                        Text(c.name).font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedCategory == c ? Color.accentColor.opacity(0.18) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedCategory == c ? Color.accentColor : Color.primary)
            }
        }
    }

    private var discountPreview: Decimal? {
        guard let amount, let original, original > amount else { return nil }
        return original - amount
    }

    private func applyDefaults() {
        if selectedCategory == nil { selectedCategory = filteredCategories.first }
        // 默认上次用的支付方式
        if selectedMethod == nil { selectedMethod = recentTx.first?.paymentMethod ?? methods.first }
        amountFocused = true
    }

    private func save() {
        guard let amount, amount > 0 else { return }
        let tx = Transaction(
            date: date,
            actualAmount: amount,
            originalAmount: original,
            kind: kind,
            category: selectedCategory,
            paymentMethod: selectedMethod,
            note: note
        )
        context.insert(tx)
        dismiss()
    }
}
