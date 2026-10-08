import SwiftUI

/// 뒤로 가기. **어느 화면에서든 왼쪽 위, 같은 모양으로 둔다.**
///
/// 예전에는 화면마다 달랐다 — 목록에서는 왼쪽 갈매기였고 상세에서는 오른쪽 X 였다. 상점에서
/// 시대 → 팩 목록 → 팩 상세로 들어가면 버튼이 왼쪽에 있다 오른쪽으로 건너뛰어서, 한 단계
/// 옮길 때마다 누를 곳을 눈으로 다시 찾아야 했다.
///
/// **누를 수 있는 넓이를 따로 잡는다.** 그림만 두면 실제로 눌리는 곳이 글리프 넓이(대략
/// 10×14pt)뿐이라 조금만 빗나가도 반응하지 않는다. 여백까지 눌리게 해 손이 닿는 크기로 만든다.
///
/// **Esc 도 이 버튼을 누른다.** 팝오버 안에서는 화면에 떠 있는 동안 내비게이션에 동작을
/// 맡겨 두고, Esc 가 오면 가장 깊은 화면의 버튼이 불린다. 버튼마다 단축키를 붙이면 상세 밑에
/// 살아 있는 목록의 버튼까지 같은 키를 잡아, 어느 쪽이 눌릴지 정해지지 않는다.
@MainActor
struct BackButton: View {
    let action: () -> Void
    /// 옆에 적을 글자. 설정·패치 노트처럼 자리가 있는 화면에서만 쓴다.
    var label: String?
    /// 마우스를 올렸을 때 뜨는 설명.
    var hint: String?

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                if let label {
                    Text(label).font(Typography.label)
                }
            }
            .foregroundStyle(.secondary)
            // 최소 28×24. 이보다 작으면 「눌러도 안 눌리는」 버튼이 된다.
            .frame(minWidth: 28, minHeight: 24, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(hint ?? label ?? "")
        .popoverEscape(action)
    }
}

extension View {
    /// 이 화면이 떠 있는 동안 Esc 에 맡길 동작. 뒤로 버튼이 없는 화면(팩 뜯기, 카드 공개)도
    /// 뒤로 버튼과 같은 줄에 선다 — 나중에 나타난 화면이 먼저 받는다. `nil` 이면 지금은 할 일이
    /// 없다는 뜻이라 Esc 가 팝오버를 닫는다.
    func popoverEscape(_ action: (() -> Void)?) -> some View {
        modifier(PopoverEscape(action: action))
    }
}

@MainActor
private struct PopoverEscape: ViewModifier {
    let action: (() -> Void)?
    /// 팝오버 밖(온라인 창 등)에서는 없다. 그때는 Esc 를 맡기지 않는다.
    @Environment(PopoverNavigation.self) private var nav: PopoverNavigation?
    @State private var handler = PopoverBackHandler()

    func body(content: Content) -> some View {
        // 화면이 다시 그려지며 넘겨받은 동작이 바뀌어도 Esc 는 늘 지금 동작을 부른다.
        handler.action = action
        return content
            .onAppear { nav?.registerBack(handler) }
            .onDisappear { nav?.unregisterBack(handler) }
    }
}
