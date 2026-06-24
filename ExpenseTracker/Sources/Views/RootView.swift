import SwiftUI
import SwiftData

/// 三个 Tab：记账 / 房贷 / 概览。
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
        }
        .task {
            // 首启种入默认分类 / 支付方式
            SeedData.seedIfNeeded(context)
        }
    }
}
