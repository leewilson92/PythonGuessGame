import SwiftUI
import SwiftData

/// 支付方式新增 / 编辑表单：名称 / 类型 / 图标。
///
/// 类型变化时联动默认图标：若用户**未手动改过**图标，则把图标更新为 `newType.defaultIcon`
/// （与模型 `init` 默认行为一致）；用户手动选过则保留。
struct PaymentMethodEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PaymentMethod.sortIndex) private var methods: [PaymentMethod]

    private let editing: PaymentMethod?

    @State private var name: String
    @State private var type: PaymentType
    @State private var icon: String
    /// 用户是否手动选过图标。手动选过后，类型变更不再覆盖图标。
    @State private var iconManuallySet: Bool

    init(editing: PaymentMethod? = nil) {
        self.editing = editing
        if let m = editing {
            _name = State(initialValue: m.name)
            _type = State(initialValue: m.type)
            _icon = State(initialValue: m.icon)
            // 已存在的支付方式，图标若与该类型默认值不同，视为用户曾自定义，保留。
            _iconManuallySet = State(initialValue: m.icon != m.type.defaultIcon)
        } else {
            _name = State(initialValue: "")
            _type = State(initialValue: .bankCard)
            _icon = State(initialValue: PaymentType.bankCard.defaultIcon)
            _iconManuallySet = State(initialValue: false)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("名称") {
                TextField("支付方式名称", text: $name)
            }

            Section("类型") {
                Picker("类型", selection: $type) {
                    ForEach(PaymentType.allCases) { Text($0.label).tag($0) }
                }
                .onChange(of: type) { _, newType in
                    // 仅类型联动更新默认图标；不触碰 iconManuallySet（用户手动选图标才置 true）。
                    if !iconManuallySet { icon = newType.defaultIcon }
                }
            }

            Section("图标") {
                // 经包装绑定捕获「用户手动选图标」，与类型联动的程序化赋值区分开。
                IconPicker(selection: Binding(
                    get: { icon },
                    set: { newIcon in
                        icon = newIcon
                        iconManuallySet = true
                    }
                ))
            }
        }
        .navigationTitle(editing == nil ? "新增支付方式" : "编辑支付方式")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
            editing.type = type
            editing.icon = icon
        } else {
            let nextIndex = (methods.map(\.sortIndex).max() ?? -1) + 1
            let m = PaymentMethod(name: trimmed, type: type, icon: icon, sortIndex: nextIndex)
            context.insert(m)
        }
        dismiss()
    }
}
