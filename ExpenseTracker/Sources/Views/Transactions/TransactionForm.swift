import Foundation

/// 「记一笔」/「编辑」表单的纯逻辑层。
///
/// 把金额字符串往返、保存校验、以及「编辑写回」从 SwiftUI 视图里抽出来，
/// 让同一份逻辑既被 `AddTransactionView` 用，也能被 XCTest 直接驱动（无需 UI）。
/// 全程 `Decimal`，禁用 `Double` 参与金额运算与往返。
enum TransactionForm {

    /// 把 `Decimal` 转成可回填进文本框的十进制字符串，保证 `parseAmount` 能严格解析回去。
    /// 用 `NSDecimalNumber(decimal:).stringValue`（十进制字符串，无千分位、无 `Double`），
    /// 与 `Decimal(string:)` 互逆，避免 `String(format:)`/`Double` 引入浮点误差。
    static func amountString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    /// 解析实付金额：去掉千分位逗号后按 `Decimal` 解析（与原「记一笔」一致）。
    static func parseAmount(_ text: String) -> Decimal? {
        Decimal(string: text.replacingOccurrences(of: ",", with: ""))
    }

    /// 解析原价。`showOriginal == false` 时一律为 `nil`（去掉优惠）。
    static func parseOriginal(_ text: String, showOriginal: Bool) -> Decimal? {
        guard showOriginal else { return nil }
        return Decimal(string: text.replacingOccurrences(of: ",", with: ""))
    }

    /// 保存校验：实付金额存在且为正。与「记一笔」`canSave` 同款规则。
    static func canSave(amountText: String) -> Bool {
        guard let amount = parseAmount(amountText), amount > 0 else { return false }
        return true
    }

    /// 把表单的各字段写回一笔已存在的交易（编辑模式）。
    ///
    /// 只改原始字段，派生值（`discount`、`MonthlySummary`）随之自动重算、不落库。
    /// `originalAmount`：`showOriginal == false` 时写 `nil`。
    /// 返回是否写入成功（金额非法时不写、返回 `false`，与 `canSave` 对齐）。
    @discardableResult
    static func apply(to transaction: Transaction,
                      amountText: String,
                      originalText: String,
                      showOriginal: Bool,
                      kind: TransactionKind,
                      category: Category?,
                      paymentMethod: PaymentMethod?,
                      date: Date,
                      note: String) -> Bool {
        guard let amount = parseAmount(amountText), amount > 0 else { return false }
        transaction.date = date
        transaction.actualAmount = amount
        transaction.originalAmount = parseOriginal(originalText, showOriginal: showOriginal)
        transaction.kind = kind
        transaction.category = category
        transaction.paymentMethod = paymentMethod
        transaction.note = note
        return true
    }
}
