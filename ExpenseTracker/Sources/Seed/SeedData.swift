import Foundation
import SwiftData

/// 首次启动时种入默认分类与支付方式。用户之后可自由增删改。
enum SeedData {

    static func seedIfNeeded(_ context: ModelContext) {
        let existingCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        if existingCategories.isEmpty {
            for (i, c) in defaultCategories.enumerated() {
                context.insert(Category(name: c.name, icon: c.icon, kind: c.kind, sortIndex: i))
            }
        }

        let existingMethods = (try? context.fetch(FetchDescriptor<PaymentMethod>())) ?? []
        if existingMethods.isEmpty {
            for (i, m) in defaultMethods.enumerated() {
                context.insert(PaymentMethod(name: m.name, type: m.type, sortIndex: i))
            }
        }
    }

    private static let defaultCategories: [(name: String, icon: String, kind: TransactionKind)] = [
        ("餐饮", "fork.knife", .expense),
        ("交通", "car.fill", .expense),
        ("购物", "bag.fill", .expense),
        ("日用", "house.fill", .expense),
        ("居住", "building.2.fill", .expense),
        ("通讯", "antenna.radiowaves.left.and.right", .expense),
        ("娱乐", "gamecontroller.fill", .expense),
        ("医疗", "cross.case.fill", .expense),
        ("人情", "gift.fill", .expense),
        ("工资", "yensign.circle.fill", .income),
        ("其他", "ellipsis.circle.fill", .income),
    ]

    private static let defaultMethods: [(name: String, type: PaymentType)] = [
        ("微信", .wechat),
        ("支付宝", .alipay),
        ("银行卡", .bankCard),
        ("信用卡", .creditCard),
    ]
}
