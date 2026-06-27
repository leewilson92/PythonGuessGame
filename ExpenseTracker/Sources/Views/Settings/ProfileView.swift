import SwiftUI

/// 「我的」Tab 根视图：下挂 分类管理 / 支付方式管理 / 数据备份。
struct ProfileView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CategoryManageView()
                    } label: {
                        Label("分类管理", systemImage: "square.grid.2x2")
                    }

                    NavigationLink {
                        PaymentMethodManageView()
                    } label: {
                        Label("支付方式管理", systemImage: "creditcard")
                    }

                    NavigationLink {
                        BudgetEditView()
                    } label: {
                        Label("预算", systemImage: "target")
                    }
                }

                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("数据备份", systemImage: "externaldrive")
                    }
                }
            }
            .navigationTitle("我的")
        }
    }
}
