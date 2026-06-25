import SwiftUI
import SwiftData

/// 分类管理：按收 / 支分两段列出，支持新增 / 改名改图标 / 删除 / 段内拖动排序。
/// 内置种子项同样可改可删（PRD 决策）。删除被引用分类走 `.nullify`，历史交易变「未分类」、金额不丢。
struct CategoryManageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.sortIndex) private var categories: [Category]

    @State private var showingAdd = false

    private func categories(of kind: TransactionKind) -> [Category] {
        categories.filter { $0.kind == kind }
    }

    var body: some View {
        List {
            section(title: "支出", kind: .expense)
            section(title: "收入", kind: .income)
        }
        .navigationTitle("分类管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { CategoryEditView() }
        }
    }

    @ViewBuilder
    private func section(title: String, kind: TransactionKind) -> some View {
        let items = categories(of: kind)
        Section(title) {
            if items.isEmpty {
                Text("暂无\(title)分类").foregroundStyle(.secondary)
            } else {
                ForEach(items) { c in
                    NavigationLink {
                        CategoryEditView(editing: c)
                    } label: {
                        Label(c.name, systemImage: c.icon)
                    }
                }
                .onDelete { offsets in delete(items, at: offsets) }
                .onMove { source, destination in
                    SortReorder.apply(items, from: source, to: destination, sortIndex: \Category.sortIndex)
                }
            }
        }
    }

    private func delete(_ items: [Category], at offsets: IndexSet) {
        for index in offsets { context.delete(items[index]) }
    }
}
