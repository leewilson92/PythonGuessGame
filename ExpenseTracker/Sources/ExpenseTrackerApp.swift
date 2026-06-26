import SwiftUI
import SwiftData

@main
struct ExpenseTrackerApp: App {
    let container: ModelContainer

    /// UI 自动化测试启动开关。检测到 `-uitest` 时用内存容器并跑首启种子，
    /// 让每次 UI 测试从干净已知状态开始，不读已有持久化数据。正常启动行为不受影响。
    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest")
    }

    init() {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: Self.isUITesting)
            container = try ModelContainer(
                for: Transaction.self, Category.self, PaymentMethod.self,
                Loan.self, LoanTranche.self, LoanPayment.self, LoanEvent.self,
                configurations: config
            )
            // 内存容器需立即种入默认数据，保证 UI 测试一上来即有种子分类 / 支付方式。
            // `seedIfNeeded` 幂等，与 `RootView.task` 的种子不冲突。
            if Self.isUITesting {
                SeedData.seedIfNeeded(container.mainContext)
            }
        } catch {
            fatalError("无法初始化数据存储: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
