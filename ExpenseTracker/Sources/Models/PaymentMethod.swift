import Foundation
import SwiftData

/// 支付方式/账户，用于「多卡对比」（哪张卡省得最多）。
/// 用户可自定义增删（例如不同银行的卡）。
@Model
final class PaymentMethod {
    var name: String
    var icon: String
    var typeRaw: String
    var sortIndex: Int

    @Relationship(deleteRule: .nullify, inverse: \Transaction.paymentMethod)
    var transactions: [Transaction] = []

    var type: PaymentType {
        get { PaymentType(rawValue: typeRaw) ?? .bankCard }
        set { typeRaw = newValue.rawValue }
    }

    init(name: String, type: PaymentType, icon: String? = nil, sortIndex: Int = 0) {
        self.name = name
        self.typeRaw = type.rawValue
        self.icon = icon ?? type.defaultIcon
        self.sortIndex = sortIndex
    }
}
