import Foundation

/// 큰 구매를 한 번 더 물을지.
///
/// 여러 팩을 사면서 잔액의 절반 이상을 쓰면 묻는다. 수량 칸을 잘못 건드려 잔액이 통째로
/// 빠지면 되돌릴 수 없다. 한 팩은 묻지 않는다 — 잔액이 적은 사람은 팩 하나에도 절반을
/// 쓰는데, 그때마다 묻는 것은 확인이 아니라 방해다.
enum PurchaseConfirmation {
    static let share = 0.5

    static func needed(quantity: Int, total: Int, balance: Int) -> Bool {
        quantity > 1 && balance > 0 && Double(total) >= Double(balance) * share
    }

    /// 잔액의 몇 %를 쓰는지. 1% 아래는 묻지 않으므로 정수로 충분하다.
    static func percent(total: Int, balance: Int) -> Int {
        Int((Double(total) / Double(max(1, balance)) * 100).rounded())
    }
}
