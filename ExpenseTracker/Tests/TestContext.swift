import Foundation
import SwiftData
@testable import ExpenseTracker

// 消歧：`Category` 与 objc/runtime.h 的 `Category` 同名，显式指向本模型。
private typealias Category = ExpenseTracker.Category

/// 测试公用：内存 `ModelContext`（不落盘），含本项目全部 `@Model`。
enum TestContext {
    static func make() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, Category.self, PaymentMethod.self,
            Loan.self, LoanTranche.self, LoanPayment.self, LoanEvent.self,
            Budget.self,
            configurations: config
        )
        return ModelContext(container)
    }

    static func count<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }
}
