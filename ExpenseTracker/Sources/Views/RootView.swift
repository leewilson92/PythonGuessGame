import SwiftUI
import SwiftData

/// 四个 Tab：记账 / 房贷 / 概览 / 我的。
struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            TransactionListView()
                .tabItem { Label("记账", systemImage: "list.bullet") }

            MortgageView()
                .tabItem { Label("房贷", systemImage: "house.fill") }

            OverviewView()
                .tabItem { Label("概览", systemImage: "chart.pie.fill") }

            ProfileView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .task {
            // 首启种入默认分类 / 支付方式
            SeedData.seedIfNeeded(context)
        }
    }
}
