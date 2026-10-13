import SwiftUI
import UIKit

extension View {
    /// Forms opt in so text editing and existing button/scroll gestures keep working.
    func keyboardDismissal() -> some View {
        modifier(KeyboardDismissalModifier())
    }
}

private struct KeyboardDismissalModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .background(KeyboardTapObserver())
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done", action: dismissKeyboard)
                        .accessibilityLabel("Dismiss keyboard")
                }
            }
            .onSubmit(dismissKeyboard)
            .onDisappear(perform: dismissKeyboard)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct KeyboardTapObserver: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardTapView { KeyboardTapView() }
    func updateUIView(_ uiView: KeyboardTapView, context: Context) {}
    static func dismantleUIView(_ uiView: KeyboardTapView, coordinator: ()) { uiView.detach() }
}

private final class KeyboardTapView: UIView, UIGestureRecognizerDelegate {
    private var tap: UITapGestureRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        detach()
        guard let window else { return }
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = self
        window.addGestureRecognizer(recognizer)
        tap = recognizer
    }

    func detach() {
        if let tap { tap.view?.removeGestureRecognizer(tap) }
        tap = nil
    }

    @objc private func dismissKeyboard() { window?.endEditing(true) }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Restrict the observer to its form. Never dismiss while positioning the
        // cursor, selecting text, or moving directly to another text field.
        guard bounds.contains(touch.location(in: self)) else { return false }
        var candidate = touch.view
        while let view = candidate {
            if view is UITextField || view is UITextView { return false }
            candidate = view.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
