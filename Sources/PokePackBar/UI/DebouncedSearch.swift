import SwiftUI

/// 검색어를 입력이 잠깐 멈춘 뒤에만 반영한다.
///
/// 카드 검색은 글자마다 카드 약 1만 9천 장을 다시 거른다. 치는 동안 매번 거르면 입력이
/// 끊기고 격자가 글자마다 다시 그려진다. 지우기(빈 검색어)는 기다리지 않고 바로 반영한다.
private struct DebouncedSearch: ViewModifier {
    let source: String
    @Binding var target: String
    let delay: Duration

    func body(content: Content) -> some View {
        content.task(id: source) {
            if source.isEmpty { target = ""; return }
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            target = source
        }
    }
}

extension View {
    func debouncedSearch(_ source: String, into target: Binding<String>,
                         delay: Duration = .milliseconds(250)) -> some View {
        modifier(DebouncedSearch(source: source, target: target, delay: delay))
    }
}
