import SwiftUI
import SwiftData

/// 支付方式管理：列出全部，支持新增 / 改名改类型改图标 / 删除 / 拖动排序。
/// 内置种子项同样可改可删。删除被引用支付方式走 `.nullify`，历史交易变「未指定」、金额不丢，
/// 概览「最省的卡」重算时按 `tx.paymentMethod?.name ?? "未指定"` 归并、忽略已删项。
struct PaymentMethodManageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PaymentMethod.sortIndex) private var methods: [PaymentMethod]

    @State private var showingAdd = false

    var body: some View {
        List {
            if methods.isEmpty {
                Text("暂无支付方式").foregroundStyle(.secondary)
            } else {
                ForEach(methods) { m in
                    NavigationLink {
                        PaymentMethodEditView(editing: m)
                    } label: {
                        HStack {
                            Label(m.name, systemImage: m.icon)
                            Spacer()
                            Text(m.type.label).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: delete)
                .onMove { source, destination in
                    SortReorder.apply(methods, from: source, to: destination, sortIndex: \PaymentMethod.sortIndex)
                }
            }
        }
        .navigationTitle("支付方式")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { PaymentMethodEditView() }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(methods[index]) }
    }
}
