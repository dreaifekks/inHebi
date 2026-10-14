import ShelfCore
import SwiftUI
import UIKit

/// UIKit buttons inside a bounded scroll view keep real focus rectangles inside this row.
struct ChipStrip: UIViewRepresentable {
  let options: [SourceOption]
  let selection: String
  @Binding var focus: BrowseFocus?
  var injectedID: String?
  var injectedRequest = 0
  func makeUIView(context: Context) -> StripView { StripView() }
  func updateUIView(_ view: StripView, context: Context) {
    view.changed = { focus = $0 }
    view.configure(
      options: options, selected: selection, injectedID: injectedID,
      injectedRequest: injectedRequest)
  }
  final class StripView: UIView {
    let scroll = UIScrollView()
    let stack = UIStackView()
    let topEntry = UIFocusGuide()
    let bottomEntry = UIFocusGuide()
    var buttons: [String: UIButton] = [:]
    var selected = ""
    var changed: (BrowseFocus?) -> Void = { _ in }
    var injection = 0
    var preferred: UIView?
    var transitionCount = 0
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
      for guide in [topEntry, bottomEntry] {
        addLayoutGuide(guide)
        NSLayoutConstraint.activate([
          guide.leadingAnchor.constraint(equalTo: leadingAnchor),
          guide.trailingAnchor.constraint(equalTo: trailingAnchor),
          guide.heightAnchor.constraint(equalToConstant: 10),
        ])
      }
      topEntry.topAnchor.constraint(equalTo: topAnchor).isActive = true
      bottomEntry.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
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
      options: [SourceOption], selected: String, injectedID: String?,
      injectedRequest: Int
    ) {
      let ids = Set(options.map(\.id))
      self.selected = ids.contains(selected) ? selected : (options.first?.id ?? "")
      let removedFocus = buttons.contains { !ids.contains($0.key) && $0.value.isFocused }
      for id in Array(buttons.keys) where !ids.contains(id) {
        let button = buttons.removeValue(forKey: id)!
        if preferred === button { preferred = nil }
        stack.removeArrangedSubview(button)
        button.removeFromSuperview()
      }
      for (index, option) in options.enumerated() {
        let button: UIButton
        if let existing = buttons[option.id] {
          button = existing
        } else {
          button = UIButton(type: .system)
          button.accessibilityIdentifier = "chip." + option.id
          buttons[option.id] = button
          NSLayoutConstraint.activate([
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: ShelfLayout.chipWidth + 60),
            button.heightAnchor.constraint(equalToConstant: 60),
          ])
        }
        if stack.arrangedSubviews.firstIndex(of: button) != index {
          stack.removeArrangedSubview(button)
          stack.insertArrangedSubview(button, at: index)
        }
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
          config.image = UIImage(systemName: FilterSymbols.chip(option.title))
          config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: FilterSymbols.pointSize, weight: .medium)
          config.imagePadding = FilterSymbols.spacing
          config.contentInsets = .init(top: 8, leading: 24, bottom: 8, trailing: 24)
          button.configuration = config
          button.accessibilityTraits = chosen ? [.button, .selected] : [.button]
        }
        button.setNeedsUpdateConfiguration()
      }
      for guide in [topEntry, bottomEntry] {
        guide.preferredFocusEnvironments = buttons[self.selected].map { [$0] } ?? []
      }
      if removedFocus {
        // Recover only an actually removed focus target; normal entry keeps the existing guides.
        DispatchQueue.main.async { [weak self] in
          guard let self else { return }
          self.changed(.chip(self.selected))
          self.preferred = self.buttons[self.selected]
          self.setNeedsFocusUpdate()
          self.updateFocusIfNeeded()
        }
      }
      if injection != injectedRequest, let injectedID {
        injection = injectedRequest
        injectFocus(id: injectedID)
      }
    }
    private func injectFocus(id: String) {
      // Only the UI timing probes request synthetic chip moves.
      DispatchQueue.main.async { [weak self] in
        guard let self, let button = self.buttons[id] else { return }
        self.preferred = button
        FocusTrace.mark("set-focus reason=test-focus-injection target=chip.\(id)")
        self.setNeedsFocusUpdate()
        self.updateFocusIfNeeded()
      }
    }
    override func didUpdateFocus(
      in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator
    ) {
      super.didUpdateFocus(in: context, with: coordinator)
      if TestMode.enabled {
        transitionCount += 1
        for button in buttons.values {
          button.accessibilityValue = "focusUpdates=\(transitionCount)"
        }
      }
      // Disable both entry guides once inside, so horizontal navigation and exits
      // remain native. No key event or movement heading participates in this rule.
      let inside = context.nextFocusedView?.isDescendant(of: self) == true
      topEntry.isEnabled = !inside
      bottomEntry.isEnabled = !inside
      if let button = context.nextFocusedView as? UIButton, button.isDescendant(of: self),
        let id = buttons.first(where: { $0.value === button })?.key
      {
        if button === preferred { preferred = nil }
        changed(.chip(id))
      } else if context.previouslyFocusedView?.isDescendant(of: self) == true {
        changed(nil)
      }
    }
  }
}
