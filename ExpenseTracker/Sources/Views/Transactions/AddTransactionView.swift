import SwiftUI
import SwiftData

/// 记一笔 / 编辑（双模式）。金额键盘优先，新建时默认值齐全（今天 / 上次用的支付方式），主打快。
///
/// - `init()`（`editing == nil`）：新建模式，行为与历史一致。
/// - `init(editing:)`（`editing != nil`）：编辑模式，逐字段预填传入交易，保存时写回同一对象、不新增记录。
struct AddTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortIndex) private var categories: [Category]
    @Query(sort: \PaymentMethod.sortIndex) private var methods: [PaymentMethod]
    @Query(sort: \Transaction.date, order: .reverse) private var recentTx: [Transaction]

    /// 待编辑的交易；`nil` 表示新建模式。
    private let editing: Transaction?

    @State private var kind: TransactionKind
    @State private var amountText: String
    @State private var originalText: String
    @State private var showOriginal: Bool
    @State private var selectedCategory: Category?
    @State private var selectedMethod: PaymentMethod?
    @State private var date: Date
    @State private var note: String

    private enum Field { case amount, original }
    @FocusState private var focusedField: Field?

    /// 双模式构造：`editing == nil` 维持新建默认值；否则用传入交易逐字段预填。
    /// `@State` 字面量默认值无法被外部参数覆盖，故编辑模式必须经此 `init` 用 `State(initialValue:)` 预填。
    init(editing: Transaction? = nil) {
        self.editing = editing
        if let tx = editing {
            _kind = State(initialValue: tx.kind)
            _amountText = State(initialValue: TransactionForm.amountString(tx.actualAmount))
            _originalText = State(initialValue: tx.originalAmount.map(TransactionForm.amountString) ?? "")
            _showOriginal = State(initialValue: tx.originalAmount != nil)
            // 直接持有 context 内的同一对象实例，保证宫格高亮 / Picker 选中命中。
            _selectedCategory = State(initialValue: tx.category)
            _selectedMethod = State(initialValue: tx.paymentMethod)
            _date = State(initialValue: tx.date)
            _note = State(initialValue: tx.note)
        } else {
            _kind = State(initialValue: .expense)
            _amountText = State(initialValue: "")
            _originalText = State(initialValue: "")
            _showOriginal = State(initialValue: false)
            _selectedCategory = State(initialValue: nil)
            _selectedMethod = State(initialValue: nil)
            _date = State(initialValue: .now)
            _note = State(initialValue: "")
        }
    }

    private var filteredCategories: [Category] {
        categories.filter { $0.kind == kind }
    }

    private var canSave: Bool { TransactionForm.canSave(amountText: amountText) }

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
                            .focused($focusedField, equals: .amount)
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
                                .focused($focusedField, equals: .original)
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
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(editing == nil ? "记一笔" : "编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
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
        guard let amount = TransactionForm.parseAmount(amountText),
              let original = TransactionForm.parseOriginal(originalText, showOriginal: showOriginal),
              original > amount else { return nil }
        return original - amount
    }

    /// 仅新建模式补默认值（今天 / 上次支付方式 / 分类首项）。
    /// 编辑模式早返回，避免覆盖 `init` 里预填的值，只设置键盘焦点。
    private func applyDefaults() {
        guard editing == nil else { focusedField = .amount; return }
        if selectedCategory == nil { selectedCategory = filteredCategories.first }
        // 默认上次用的支付方式
        if selectedMethod == nil { selectedMethod = recentTx.first?.paymentMethod ?? methods.first }
        focusedField = .amount
    }

    private func save() {
        if let editing {
            // 编辑模式：写回同一对象，不 insert。
            TransactionForm.apply(
                to: editing,
                amountText: amountText,
                originalText: originalText,
                showOriginal: showOriginal,
                kind: kind,
                category: selectedCategory,
                paymentMethod: selectedMethod,
                date: date,
                note: note
            )
        } else {
            // 新建模式：插入新交易（行为不变）。
            guard let amount = TransactionForm.parseAmount(amountText), amount > 0 else { return }
            let tx = Transaction(
                date: date,
                actualAmount: amount,
                originalAmount: TransactionForm.parseOriginal(originalText, showOriginal: showOriginal),
                kind: kind,
                category: selectedCategory,
                paymentMethod: selectedMethod,
                note: note
            )
            context.insert(tx)
        }
        dismiss()
    }
}
