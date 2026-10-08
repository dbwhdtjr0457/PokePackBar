import SwiftUI

/// 탭 맨 위 검색창. 컬렉션, 도감, 상점, 팩 탭이 같은 모양을 쓴다.
///
/// 검색은 한 줄을 통째로 쓴다. 보기 줄 사이에 끼워 두니 글자 두 개 폭으로 줄어
/// 무엇을 쳤는지도 보이지 않았다. Esc 로 검색어를 지운다.
@MainActor
struct SearchField: View {
    let placeholder: String
    let label: String
    let clearLabel: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Typography.body)
                .accessibilityLabel(label)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "multiply.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .onExitCommand { text = "" }
    }
}
