import Foundation
import SwiftData

/// 记账分类。首次启动种入一组常用分类，用户可增删改。
@Model
final class Category {
    var name: String
    /// SF Symbol 名
    var icon: String
    /// 这个分类属于支出还是收入
    var kindRaw: String
    /// 排序用
    var sortIndex: Int

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(name: String, icon: String, kind: TransactionKind, sortIndex: Int = 0) {
        self.name = name
        self.icon = icon
        self.kindRaw = kind.rawValue
        self.sortIndex = sortIndex
    }
}
