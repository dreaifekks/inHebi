import ShelfCore
import SwiftUI
import UIKit

/// UIKit buttons inside a bounded scroll view keep real focus rectangles inside this row.
struct ChipStrip: UIViewRepresentable {
  let options: [SourceOption]
  let selection: String
  @Binding var focus: BrowseFocus?
  let focusRequest: Int
  var injectedID: String?
  var injectedRequest = 0
  func makeUIView(context: Context) -> StripView { StripView() }
  func updateUIView(_ view: StripView, context: Context) {
    view.changed = { focus = $0 }
    view.configure(
      options: options, selected: selection, focusRequest: focusRequest, injectedID: injectedID,
      injectedRequest: injectedRequest)
  }
  final class StripView: UIView {
    let scroll = UIScrollView()
    let stack = UIStackView()
    var buttons: [String: UIButton] = [:]
    var selected = ""
    var changed: (BrowseFocus?) -> Void = { _ in }
    var request = 0
    var injection = 0
    var preferred: UIView?
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
      if let preferred { return [preferred] }
      if let button = buttons[selected] { return [button] }
      return super.preferredFocusEnvironments
    }
    init() {
      super.init(frame: .zero)
      scroll.translatesAutoresizingMaskIntoConstraints = false
      scroll.contentInsetAdjustmentBehavior = .never
      scroll.showsHorizontalScrollIndicator = false
      stack.translatesAutoresizingMaskIntoConstraints = false
      stack.axis = .horizontal
      stack.alignment = .center
      stack.spacing = ShelfLayout.chipSpacing
      addSubview(scroll)
      scroll.addSubview(stack)
      NSLayoutConstraint.activate([
        scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
        scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
        scroll.topAnchor.constraint(equalTo: topAnchor),
        scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        stack.leadingAnchor.constraint(
          equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
        stack.trailingAnchor.constraint(
          equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
        stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
        stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
        stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
      ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(
      options: [SourceOption], selected: String, focusRequest: Int, injectedID: String?,
      injectedRequest: Int
    ) {
      self.selected = selected
      for option in options {
        if buttons[option.id] == nil {
          let button = UIButton(type: .system)
          button.accessibilityIdentifier = "chip." + option.id
          button.accessibilityLabel = option.title
          button.setTitle(option.title, for: .normal)
          button.configurationUpdateHandler = { [weak self] button in
            guard let self else { return }
            var config = UIButton.Configuration.filled()
            config.cornerStyle = .capsule
            config.title = option.title
            config.attributedTitle = AttributedString(
              option.title, attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 29)]))
            let chosen = self.selected == option.id
            config.baseBackgroundColor =
              button.isFocused ? .white : (chosen ? .cyan : UIColor(white: 0.2, alpha: 1))
            config.baseForegroundColor = button.isFocused || chosen ? .black : .white
            config.image = UIImage(systemName: "checkmark")?.withTintColor(
              chosen ? .black : .clear, renderingMode: .alwaysOriginal)
            config.imagePadding = 10
            config.contentInsets = .init(top: 8, leading: 24, bottom: 8, trailing: 24)
            button.configuration = config
            button.accessibilityTraits = chosen ? [.button, .selected] : [.button]
          }
          buttons[option.id] = button
          stack.addArrangedSubview(button)
          NSLayoutConstraint.activate([
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: ShelfLayout.chipWidth + 60),
            button.heightAnchor.constraint(equalToConstant: 60),
          ])
        }
        buttons[option.id]?.setNeedsUpdateConfiguration()
      }
      if injection != injectedRequest, let injectedID {
        injection = injectedRequest
        requestFocus(id: injectedID, reason: "test-focus-injection")
      }
      if request != focusRequest {
        request = focusRequest
        requestFocus(id: selected, reason: "menu")
      }
    }
    private func requestFocus(id: String, reason: String, from origin: UIView? = nil) {
      // Representable updates and didUpdateFocus both run inside UIKit update passes.
      DispatchQueue.main.async { [weak self, weak origin] in
        guard let self, let button = self.buttons[id] else { return }
        if reason == "strip-entry" && origin?.isFocused != true { return }
        self.preferred = button
        FocusTrace.mark("set-focus reason=\(reason) target=chip.\(id)")
        let current = UIFocusSystem.focusSystem(for: self)?.focusedItem as? UIView
        if current?.isDescendant(of: self) == true {
          self.setNeedsFocusUpdate()
          self.updateFocusIfNeeded()
        } else {
          // Only an environment containing the current item can request a focus update.
          self.window?.rootViewController?.setNeedsFocusUpdate()
          self.window?.rootViewController?.updateFocusIfNeeded()
        }
        // Keep the preference until didUpdateFocus confirms the transfer.
      }
    }
    override func didUpdateFocus(
      in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator
    ) {
      super.didUpdateFocus(in: context, with: coordinator)
      if let button = context.nextFocusedView as? UIButton, button.isDescendant(of: self),
        let id = buttons.first(where: { $0.value === button })?.key
      {
        if button === preferred { preferred = nil }
        var previous = context.previouslyFocusedView
        var fromAnotherRow = previous == nil
        while let node = previous {
          if node is UITabBar || node.accessibilityIdentifier == "browse.grid" {
            fromAnotherRow = true
            break
          }
          previous = node.superview
        }
        if fromAnotherRow, id != selected {
          requestFocus(id: selected, reason: "strip-entry", from: button)
          return
        }
        changed(.chip(id))
      } else if context.previouslyFocusedView?.isDescendant(of: self) == true {
        changed(nil)
      }
    }
  }
}
