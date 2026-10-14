import SwiftUI
import UIKit

/// Observe the actual UIKit Tab -> content boundary, not transient nil SwiftUI focus values.
struct TabFocusEntry: UIViewRepresentable {
  let entered: () -> Void
  func makeUIView(context: Context) -> EntryView { EntryView(entered: entered) }
  func updateUIView(_ view: EntryView, context: Context) { view.entered = entered }
  final class EntryView: UIView {
    var entered: () -> Void
    init(entered: @escaping () -> Void) {
      self.entered = entered
      super.init(frame: .zero)
      isUserInteractionEnabled = false
      NotificationCenter.default.addObserver(
        self, selector: #selector(focusChanged), name: UIFocusSystem.didUpdateNotification,
        object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func focusChanged(_ notification: Notification) {
      guard window != nil,
        let context = notification.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey]
          as? UIFocusUpdateContext,
        context.focusHeading.contains(.down), let previous = context.previouslyFocusedView
      else { return }
      var responder: UIResponder? = self
      while let current = responder {
        if let controller = current as? UITabBarController {
          if previous.isDescendant(of: controller.tabBar) {
            // Let SwiftUI receive the UIKit update before requesting the chip.
            DispatchQueue.main.async { [weak self] in self?.entered() }
          }
          return
        }
        responder = current.next
      }
    }
  }
}
