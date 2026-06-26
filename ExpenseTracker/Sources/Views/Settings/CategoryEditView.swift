import SwiftUI
import SwiftData

/// 分类新增 / 编辑表单：名称 / 图标 / 收支类型（kind）。
///
/// - 新增（`editing == nil`）：kind 可选；保存时 `sortIndex` = 该 kind 现有最大 +1。
/// - 编辑（`editing != nil`）：kind 只读（PRD 决策：分类自身 kind 不可改），仅写回名称 / 图标 / （展示）kind。
struct CategoryEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortIndex) private var categories: [Category]

    private let editing: Category?

    @State private var name: String
    @State private var icon: String
    @State private var kind: TransactionKind

    init(editing: Category? = nil) {
        self.editing = editing
        if let c = editing {
            _name = State(initialValue: c.name)
            _icon = State(initialValue: c.icon)
            _kind = State(initialValue: c.kind)
        } else {
            _name = State(initialValue: "")
            _icon = State(initialValue: IconCatalog.all.first ?? "circle.fill")
            _kind = State(initialValue: .expense)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("名称") {
                TextField("分类名称", text: $name)
            }

            Section("收支类型") {
                if editing == nil {
                    Picker("收支类型", selection: $kind) {
                        ForEach(TransactionKind.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } else {
                    // 编辑模式 kind 只读
                    HStack {
                        Text("收支类型")
                        Spacer()
                        Text(kind.label).foregroundStyle(.secondary)
                    }
                }
            }

            Section("图标") {
                IconPicker(selection: $icon)
            }
        }
        .navigationTitle(editing == nil ? "新增分类" : "编辑分类")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 「取消」：sheet 新增路径提供显式退出（与 AddTransactionView 一致）；
            // push 编辑路径有系统返回，再加一个取消也安全（同样 dismiss 当前层级）。
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save).disabled(!canSave)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let editing {
            editing.name = trimmed
            editing.icon = icon
            // kind 不可改，不写回 kind
        } else {
            let nextIndex = (categories.filter { $0.kind == kind }.map(\.sortIndex).max() ?? -1) + 1
            let c = Category(name: trimmed, icon: icon, kind: kind, sortIndex: nextIndex)
            context.insert(c)
        }
        dismiss()
    }
}
