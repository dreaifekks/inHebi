import Foundation
import UIKit

@MainActor enum FocusTrace {
  #if DEBUG
    private static let recorder = Recorder()
    static var state: String {
      get { recorder.state }
      set { recorder.state = newValue }
    }
    static func focusChanged(old: String, new: String) {
      recorder.write("kind=focus-state direction=\(recorder.heading) prevID=\(old) nextID=\(new)")
    }
    static func mark(_ text: String) { recorder.write("kind=code " + text) }
    static func describe(_ view: UIView?) -> String {
      guard let view else { return "nil" }
      var parts: [String] = []
      var node: UIView? = view
      while let current = node, parts.count < 10 {
        let frame = current.convert(current.bounds, to: nil)
        parts.append(
          "\(String(describing: type(of: current)).split(separator: "<").first ?? "View")#\(current.accessibilityIdentifier ?? "-")@\(Int(frame.minX)),\(Int(frame.minY)),\(Int(frame.width)),\(Int(frame.height))"
        )
        node = current.superview
      }
      return parts.joined(separator: "<")
    }
    @MainActor private final class Recorder: NSObject {
      var heading = "none"
      private let writer = DispatchQueue(label: "inHebi.FocusTrace")
      var state = "scope=launch focus=nil selection=- count=0 loading=true"
      var lines: [String] = []
      let file: URL
      override init() {
        file = URL.cachesDirectory.appendingPathComponent("inHebi/FocusTrace.txt")
        super.init()
        try? FileManager.default.createDirectory(
          at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let prior = try? String(contentsOf: file, encoding: .utf8) {
          lines = prior.split(separator: "\n").suffix(499).map(String.init)
        }
        NotificationCenter.default.addObserver(
          self, selector: #selector(changed), name: UIFocusSystem.didUpdateNotification, object: nil
        )
        NotificationCenter.default.addObserver(
          self, selector: #selector(failed), name: UIFocusSystem.movementDidFailNotification,
          object: nil)
        write(
          "kind=start DEBUG=true testMode=\(TestMode.enabled) prefs=\(TestMode.enabled ? "test-suite" : "standard") build=\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "-") revision=\(Bundle.main.object(forInfoDictionaryKey: "ShelfCommit") ?? "-")"
        )
      }
      @objc func changed(_ note: Notification) { event(note, kind: "native") }
      @objc func failed(_ note: Notification) { event(note, kind: "native-failed") }
      func event(_ note: Notification, kind: String) {
        guard
          let context = note.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey]
            as? UIFocusUpdateContext
        else { return }
        var headings: [String] = []
        for (flag, name): (UIFocusHeading, String) in [
          (.up, "up"), (.down, "down"), (.left, "left"), (.right, "right"),
        ] {
          if context.focusHeading.contains(flag) { headings.append(name) }
        }
        heading = headings.isEmpty ? "none" : headings.joined(separator: "+")
        write(
          "kind=\(kind) direction=\(headings.joined(separator: "+")) prev=\(FocusTrace.describe(context.previouslyFocusedView)) next=\(FocusTrace.describe(context.nextFocusedView))"
        )
      }
      func write(_ event: String) {
        lines.append(
          Date.now.ISO8601Format(
            .iso8601.year().month().day().time(includingFractionalSeconds: true)) + " " + event
            + " " + state)
        if lines.count > 500 { lines.removeFirst(lines.count - 500) }
        let snapshot = lines.joined(separator: "\n") + "\n"
        let destination = file
        writer.async { try? snapshot.write(to: destination, atomically: true, encoding: .utf8) }
      }
    }
  #else
    static func focusChanged(old: String, new: String) {}
    static var state: String {
      get { "" }
      set {}
    }
    static func mark(_ text: String) {}
    static func describe(_ view: UIView?) -> String { "" }
  #endif
}
