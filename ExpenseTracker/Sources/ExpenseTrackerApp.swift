import SwiftUI
import SwiftData

@main
struct ExpenseTrackerApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Transaction.self, Category.self, PaymentMethod.self,
                Loan.self, LoanTranche.self, LoanPayment.self, LoanEvent.self
            )
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
