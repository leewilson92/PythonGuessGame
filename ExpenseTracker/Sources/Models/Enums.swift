import Foundation

/// 一笔账是支出还是收入。第一版以支出为主，收入端（工资等）整体留到 v2，
/// 但模型先把口子留好。
enum TransactionKind: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }

    var label: String {
        switch self {
        case .expense: return "支出"
        case .income: return "收入"
        }
    }
}

/// 支付方式/账户类型，用于「多卡对比」。
/// 信用卡消费照常记为支出；之后“还信用卡”不另记支出，避免同一笔钱算两遍。
enum PaymentType: String, Codable, CaseIterable, Identifiable {
    case wechat
    case alipay
    case bankCard
    case creditCard
    case cash

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wechat: return "微信"
        case .alipay: return "支付宝"
        case .bankCard: return "银行卡"
        case .creditCard: return "信用卡"
        case .cash: return "现金"
        }
    }

    /// 默认 SF Symbol 图标。
    var defaultIcon: String {
        switch self {
        case .wechat: return "message.fill"
        case .alipay: return "a.circle.fill"
        case .bankCard: return "creditcard.fill"
        case .creditCard: return "creditcard"
        case .cash: return "banknote.fill"
        }
    }
}

/// 还款方式。MVP 只做等额本息（最常见）；等额本金留作 v2。
enum RepaymentMethod: String, Codable, CaseIterable, Identifiable {
    case equalInstallment   // 等额本息

    var id: String { rawValue }

    var label: String {
        switch self {
        case .equalInstallment: return "等额本息"
        }
    }
}

/// 房贷上影响计算的手动事件：提前还款 / 改利率。
enum LoanEventType: String, Codable, CaseIterable, Identifiable {
    case prepayment   // 提前还款
    case rateChange   // 改利率

    var id: String { rawValue }

    var label: String {
        switch self {
        case .prepayment: return "提前还款"
        case .rateChange: return "调整利率"
        }
    }
}
