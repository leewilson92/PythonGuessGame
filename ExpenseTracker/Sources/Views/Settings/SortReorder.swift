import Foundation

/// 拖动排序后的 `sortIndex` 段内写回逻辑（分类 / 支付方式通用）。
///
/// 抽成纯函数便于 XCTest 直接驱动：传入「当前段的有序数组 + onMove 的 from/to」，
/// 先 `move(fromOffsets:toOffset:)` 重排，再按新下标连续赋 `sortIndex`。
/// 段内连续即可（`@Query` 先全局按 `sortIndex` 排、再 `filter`，段内相对顺序稳定即生效），
/// 不追求全局唯一，避免一次移动要重排所有项。
enum SortReorder {
    /// 对一个「段」内的可排序项应用移动并写回 `sortIndex`。
    /// - Parameters:
    ///   - items: 当前段的有序数组（来源已按 `sortIndex` 升序）。
    ///   - source: `onMove` 提供的源下标集合。
    ///   - destination: `onMove` 提供的目标下标。
    ///   - sortIndex: 读写某项 `sortIndex` 的键路径写访问。
    static func apply<Item>(_ items: [Item],
                            from source: IndexSet,
                            to destination: Int,
                            sortIndex: ReferenceWritableKeyPath<Item, Int>) {
        var ordered = items
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, item) in ordered.enumerated() {
            item[keyPath: sortIndex] = i
        }
    }
}
