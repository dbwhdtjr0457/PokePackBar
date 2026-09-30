import SwiftUI

/// 기존 Stepper의 증감 버튼은 유지하고, 가운데 숫자를 누르면 직접 입력할 수 있게 한다.
@MainActor
struct PackQuantityStepper: View {
    @Environment(PopoverNavigation.self) private var navigation

    @Binding var quantity: Int
    let maximum: Int
    let showsMultiplier: Bool
    let accessibilityLabel: String
    let l: L

    @State private var isEditing = false
    @State private var draft = ""

    private var normalizedMaximum: Int { max(1, maximum) }
    private var validatedDraft: Int? {
        PackQuantitySelection.validated(draft, maximum: normalizedMaximum)
    }

    var body: some View {
        HStack(spacing: 4) {
            Button(action: beginEditing) {
                Text(showsMultiplier ? "×\(quantity)" : "\(quantity)")
                    .monospacedDigit()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(l.packQuantityInputTitle)
            .accessibilityLabel(l.packQuantityInputTitle)

            Stepper("", value: $quantity, in: 1...normalizedMaximum)
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel(accessibilityLabel)
        }
        .alert(l.packQuantityInputTitle, isPresented: $isEditing) {
            TextField(l.packQuantityInputPlaceholder, text: $draft)
            Button(l.cancel, role: .cancel) {}
            Button(l.done, action: applyDraft)
                .keyboardShortcut(.defaultAction)
                .disabled(validatedDraft == nil)
        } message: {
            Text(l.packQuantityInputRange(normalizedMaximum))
        }
        // 메인 팝오버보다 오래 사는 SwiftUI 트리를 재사용한다. 숫자 입력 alert 를 띄운 채
        // 메인 팝오버가 닫히면 AppKit sheet 만 사라지고 `isEditing` 이 남아, 다시 열었을 때
        // 보이지 않는 모달이 입력을 막는다. 화면 진행 상태는 보존하되 일시적인 입력만 버린다.
        .onChange(of: navigation.isShown) { _, isShown in
            guard !isShown else { return }
            dismissEditor()
        }
    }

    private func beginEditing() {
        draft = String(quantity)
        isEditing = true
    }

    private func applyDraft() {
        guard let value = validatedDraft else { return }
        quantity = value
    }

    private func dismissEditor() {
        isEditing = false
        draft = ""
    }
}
