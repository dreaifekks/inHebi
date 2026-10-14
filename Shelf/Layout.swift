import ShelfCore
import SwiftUI

enum ShelfLayout {
  static let horizontalInset: CGFloat = 80
  static let videoColumns = 4
  static let portraitColumns = 5
  static let videoSpacing: CGFloat = 48
  static let portraitSpacing: CGFloat = 40
  static let rowSpacing: CGFloat = 40
  static let coverTitleSpacing: CGFloat = 32
  static let chipWidth: CGFloat = 160
  static let chipSpacing: CGFloat = 24
  static let filterHeight: CGFloat = 80
  static let filterFixedWidth: CGFloat = 470
  static let cardRadius: CGFloat = 16
  static let cardPixels = 900
  static let detailPixels = 1600
  static let readerPixels = 2400
  static let titleFont = Font.system(size: 29, weight: .medium)
  static let detailFont = Font.system(size: 48, weight: .bold)
  static let captionFont = Font.system(size: 25)
}

enum MediaText {
  static func duration(_ seconds: Double?) -> String {
    guard let seconds else { return "" }
    let value = Int(seconds)
    return value >= 3600
      ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
      : String(format: "%d:%02d", value / 60, value % 60)
  }
  static func count(_ value: Int?) -> String? {
    value.map { $0 >= 10_000 ? String(format: "%.1f万", Double($0) / 10_000) : String($0) }
  }
  static func date(_ text: String?) -> String? {
    guard let text, !text.isEmpty else { return nil }
    guard text.contains("T") else { return text }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: text) else { return String(text.prefix(10)) }
    let days = Int(Date().timeIntervalSince(date) / 86400)
    if days == 0 { return "今天" }
    if days < 30 { return "\(days) 天前" }
    return String(text.prefix(10))
  }
  static func joined(_ values: [String?]) -> String {
    values.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
  }
}

@MainActor enum TestMode {
  static var enabled: Bool {
    #if DEBUG
      ProcessInfo.processInfo.arguments.contains("--ui-testing")
    #else
      false
    #endif
  }
  static var preferences: UserDefaults {
    enabled ? UserDefaults(suiteName: "com.dreaife.shelf.uitests.preferences")! : .standard
  }
}
@MainActor @Observable final class PlaybackActivity {
  static let shared = PlaybackActivity()
  var active = false
  var stoppedTime = 0.0
}
