import Foundation

/// 팩 수량 직접 입력은 구매와 개봉에서 같은 규칙을 쓴다.
///
/// 최대값은 임의의 배치 제한이 아니라 구매 가능한 수량 또는 실제 보유량이다.
enum PackQuantitySelection {
    static func validated(_ text: String, maximum: Int) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard maximum > 0,
              let value = Int(trimmed),
              value > 0,
              value <= maximum else { return nil }
        return value
    }
}
