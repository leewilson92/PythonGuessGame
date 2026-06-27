import Foundation
import SwiftData

/// 一笔账（消费或收入）。
///
/// 「优惠」不单独存：`优惠 = originalAmount - actualAmount`，原价为空时优惠为 0。
@Model
final class Transaction {
    var date: Date
    /// 实付金额
    var actualAmount: Decimal
    /// 原价，可空。填了才有优惠。
    var originalAmount: Decimal?
    var kindRaw: String
    var note: String

    @Relationship(deleteRule: .nullify)
    var category: Category?

    @Relationship(deleteRule: .nullify)
    var paymentMethod: PaymentMethod?

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    /// 这一笔省下了多少（原价 − 实付），无原价时为 0。
    var discount: Decimal {
        guard let original = originalAmount, original > actualAmount else { return 0 }
        return original - actualAmount
    }

    init(date: Date = .now,
         actualAmount: Decimal,
         originalAmount: Decimal? = nil,
         kind: TransactionKind = .expense,
         category: Category? = nil,
         paymentMethod: PaymentMethod? = nil,
         note: String = "") {
        self.date = date
        self.actualAmount = actualAmount
        self.originalAmount = originalAmount
        self.kindRaw = kind.rawValue
        self.category = category
        self.paymentMethod = paymentMethod
        self.note = note
    }
}
