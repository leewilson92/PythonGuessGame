import Foundation
import SwiftData

/// 数据备份：把全部数据导出成一个 JSON 文件，可分享到 iCloud 文件/微信/邮箱；
/// 换机时导入恢复。这是 v1 没有 iCloud 同步时的安全网。
///
/// 导入采用「清空后整体恢复」策略，避免重复。
enum BackupManager {

    // MARK: - Codable 快照

    struct Snapshot: Codable {
        var version: Int = 1
        var exportedAt: Date = .now
        var categories: [CategoryDTO] = []
        var paymentMethods: [PaymentMethodDTO] = []
        var transactions: [TransactionDTO] = []
        var loans: [LoanDTO] = []
    }

    struct CategoryDTO: Codable {
        var id: String
        var name: String
        var icon: String
        var kind: String
        var sortIndex: Int
    }

    struct PaymentMethodDTO: Codable {
        var id: String
        var name: String
        var icon: String
        var type: String
        var sortIndex: Int
    }

    struct TransactionDTO: Codable {
        var date: Date
        var actualAmount: Decimal
        var originalAmount: Decimal?
        var kind: String
        var note: String
        var categoryID: String?
        var paymentMethodID: String?
    }

    struct LoanDTO: Codable {
        var name: String
        var tranches: [TrancheDTO]
    }

    struct TrancheDTO: Codable {
        var name: String
        var openingPrincipal: Decimal
        var originalTerms: Int
        var currentPrincipal: Decimal
        var annualRate: Decimal
        var remainingTerms: Int
        var repaymentMethod: String
        var payments: [PaymentDTO]
        var events: [EventDTO]
    }

    struct PaymentDTO: Codable {
        var date: Date
        var totalAmount: Decimal
        var principal: Decimal
        var interest: Decimal
    }

    struct EventDTO: Codable {
        var date: Date
        var type: String
        var amount: Decimal?
        var newAnnualRate: Decimal?
    }

    // MARK: - 导出

    static func export(from context: ModelContext) throws -> Data {
        var snapshot = Snapshot()

        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        var categoryIDs: [Category: String] = [:]
        for c in categories {
            let id = UUID().uuidString
            categoryIDs[c] = id
            snapshot.categories.append(.init(id: id, name: c.name, icon: c.icon, kind: c.kindRaw, sortIndex: c.sortIndex))
        }

        let methods = (try? context.fetch(FetchDescriptor<PaymentMethod>())) ?? []
        var methodIDs: [PaymentMethod: String] = [:]
        for m in methods {
            let id = UUID().uuidString
            methodIDs[m] = id
            snapshot.paymentMethods.append(.init(id: id, name: m.name, icon: m.icon, type: m.typeRaw, sortIndex: m.sortIndex))
        }

        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        for t in transactions {
            snapshot.transactions.append(.init(
                date: t.date,
                actualAmount: t.actualAmount,
                originalAmount: t.originalAmount,
                kind: t.kindRaw,
                note: t.note,
                categoryID: t.category.flatMap { categoryIDs[$0] },
                paymentMethodID: t.paymentMethod.flatMap { methodIDs[$0] }
            ))
        }

        let loans = (try? context.fetch(FetchDescriptor<Loan>())) ?? []
        for loan in loans {
            let tranches = loan.tranches.map { tr in
                TrancheDTO(
                    name: tr.name,
                    openingPrincipal: tr.openingPrincipal,
                    originalTerms: tr.originalTerms,
                    currentPrincipal: tr.currentPrincipal,
                    annualRate: tr.annualRate,
                    remainingTerms: tr.remainingTerms,
                    repaymentMethod: tr.repaymentMethodRaw,
                    payments: tr.payments.map { .init(date: $0.date, totalAmount: $0.totalAmount, principal: $0.principal, interest: $0.interest) },
                    events: tr.events.map { .init(date: $0.date, type: $0.typeRaw, amount: $0.amount, newAnnualRate: $0.newAnnualRate) }
                )
            }
            snapshot.loans.append(.init(name: loan.name, tranches: tranches))
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    // MARK: - 导入（清空后整体恢复）

    static func restore(from data: Data, into context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(Snapshot.self, from: data)

        // 清空现有数据
        for t in (try? context.fetch(FetchDescriptor<Transaction>())) ?? [] { context.delete(t) }
        for l in (try? context.fetch(FetchDescriptor<Loan>())) ?? [] { context.delete(l) }
        for c in (try? context.fetch(FetchDescriptor<Category>())) ?? [] { context.delete(c) }
        for m in (try? context.fetch(FetchDescriptor<PaymentMethod>())) ?? [] { context.delete(m) }

        var categoryMap: [String: Category] = [:]
        for dto in snapshot.categories {
            let c = Category(name: dto.name, icon: dto.icon, kind: TransactionKind(rawValue: dto.kind) ?? .expense, sortIndex: dto.sortIndex)
            context.insert(c)
            categoryMap[dto.id] = c
        }

        var methodMap: [String: PaymentMethod] = [:]
        for dto in snapshot.paymentMethods {
            let m = PaymentMethod(name: dto.name, type: PaymentType(rawValue: dto.type) ?? .bankCard, icon: dto.icon, sortIndex: dto.sortIndex)
            context.insert(m)
            methodMap[dto.id] = m
        }

        for dto in snapshot.transactions {
            let t = Transaction(
                date: dto.date,
                actualAmount: dto.actualAmount,
                originalAmount: dto.originalAmount,
                kind: TransactionKind(rawValue: dto.kind) ?? .expense,
                category: dto.categoryID.flatMap { categoryMap[$0] },
                paymentMethod: dto.paymentMethodID.flatMap { methodMap[$0] },
                note: dto.note
            )
            context.insert(t)
        }

        for loanDTO in snapshot.loans {
            let loan = Loan(name: loanDTO.name)
            context.insert(loan)
            for trDTO in loanDTO.tranches {
                let tr = LoanTranche(
                    name: trDTO.name,
                    openingPrincipal: trDTO.openingPrincipal,
                    annualRate: trDTO.annualRate,
                    remainingTerms: trDTO.remainingTerms,
                    repaymentMethod: RepaymentMethod(rawValue: trDTO.repaymentMethod) ?? .equalInstallment
                )
                tr.currentPrincipal = trDTO.currentPrincipal
                tr.originalTerms = trDTO.originalTerms
                tr.loan = loan
                context.insert(tr)
                for p in trDTO.payments {
                    let payment = LoanPayment(date: p.date, totalAmount: p.totalAmount, principal: p.principal, interest: p.interest, tranche: tr)
                    context.insert(payment)
                }
                for e in trDTO.events {
                    let event = LoanEvent(date: e.date, type: LoanEventType(rawValue: e.type) ?? .prepayment, amount: e.amount, newAnnualRate: e.newAnnualRate, tranche: tr)
                    context.insert(event)
                }
            }
        }

        try context.save()
    }
}
