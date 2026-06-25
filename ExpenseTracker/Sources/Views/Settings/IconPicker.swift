import SwiftUI

/// 预置 SF Symbol 图标集。分类编辑、支付方式编辑共用。
///
/// 必须包含 `SeedData` 现用的全部分类图标与 `PaymentType.defaultIcon` 的全部图标，
/// 保证内置种子项编辑时能在列表里命中高亮。只给预置组，不做任意搜索/输入。
enum IconCatalog {
    /// 全部可选图标（去重后保持稳定顺序）。供 `IconPicker` 与单测引用。
    static let all: [String] = {
        var seen = Set<String>()
        return grouped.flatMap { $0.icons }.filter { seen.insert($0).inserted }
    }()

    /// 按用途分组（便于浏览，也便于核对覆盖面）。
    static let grouped: [(title: String, icons: [String])] = [
        ("餐饮", ["fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill", "birthday.cake.fill", "wineglass.fill"]),
        ("交通", ["car.fill", "bus.fill", "tram.fill", "airplane", "fuelpump.fill", "bicycle"]),
        ("购物", ["bag.fill", "cart.fill", "handbag.fill", "tshirt.fill", "shippingbox.fill"]),
        ("居住日用", ["house.fill", "building.2.fill", "lightbulb.fill", "drop.fill", "washer.fill", "wrench.and.screwdriver.fill"]),
        ("通讯娱乐", ["antenna.radiowaves.left.and.right", "wifi", "gamecontroller.fill", "film.fill", "music.note", "book.fill"]),
        ("医疗", ["cross.case.fill", "pills.fill", "heart.fill", "stethoscope"]),
        ("人情教育", ["gift.fill", "graduationcap.fill", "person.2.fill", "pawprint.fill", "figure.run"]),
        ("收入", ["yensign.circle.fill", "dollarsign.circle.fill", "banknote.fill", "chart.line.uptrend.xyaxis", "briefcase.fill"]),
        ("卡片现金", ["creditcard", "creditcard.fill", "wallet.pass.fill", "a.circle.fill", "message.fill"]),
        ("通用", ["ellipsis.circle.fill", "star.fill", "tag.fill", "tray.fill", "circle.fill"]),
    ]
}

/// 图标选择宫格。当前选中高亮，点选写回绑定。复用于分类 / 支付方式编辑。
struct IconPicker: View {
    @Binding var selection: String

    private let columns = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(IconCatalog.all, id: \.self) { icon in
                Button {
                    selection = icon
                } label: {
                    Image(systemName: icon)
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection == icon ? Color.accentColor.opacity(0.18) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == icon ? Color.accentColor : Color.primary)
            }
        }
    }
}
