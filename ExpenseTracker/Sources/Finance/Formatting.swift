import Foundation

/// 金额/百分比格式化工具。默认人民币。
enum Money {
    static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "CNY"
        f.locale = Locale(identifier: "zh_CN")
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    static func string(_ value: Decimal) -> String {
        currencyFormatter.string(from: value as NSDecimalNumber) ?? "¥0.00"
    }

    /// 把年利率（0.031）显示成 3.10%。
    static func percent(_ rate: Decimal) -> String {
        let pct = (rate * 100) as Decimal
        return String(format: "%.2f%%", NSDecimalNumber(decimal: pct).doubleValue)
    }
}
