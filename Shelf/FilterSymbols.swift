import Foundation

/// Display labels are shared across sources; flattened comic labels use their leaf category.
enum FilterSymbols {
  static let chips: [String: String] = [
    "趋势": "chart.line.uptrend.xyaxis", "最新": "clock", "热门": "flame",
    "播放": "play.circle", "喜欢": "heart", "全部": "square.grid.2x2",
    "裏番": "film", "泡麵番": "timer", "Motion Anime": "wand.and.stars",
    "3DCG": "cube", "2.5D": "square.stack.3d.up", "2D動畫": "paintbrush",
    "AI生成": "sparkles", "MMD": "music.note", "Cosplay": "theatermasks",
    "新番預告": "calendar.badge.clock", "同人誌": "book.closed", "單行本": "books.vertical",
    "雜誌&短篇": "newspaper", "韓漫": "scroll", "漢化": "character.book.closed.zh",
    "日語": "character.book.closed.ja", "English": "character.book.closed",
    "CG畫集": "photo.on.rectangle", "AI圖集": "sparkles", "3D漫畫": "cube",
    "合集": "square.stack", "其他": "ellipsis.circle",
  ]
  static let fallback = "tag"
  static let sort = "arrow.up.arrow.down"
  static let rating = "line.3.horizontal.decrease"
  static let search = "magnifyingglass"
  static let pointSize: CGFloat = 26
  static let spacing: CGFloat = 12

  static func chip(_ title: String) -> String {
    let leaf = title.split(separator: "·").last.map(String.init) ?? title
    return chips[leaf.trimmingCharacters(in: .whitespaces)] ?? fallback
  }
  static func control(_ title: String) -> String {
    title.hasPrefix("分级") ? rating : sort
  }
  static var allNames: Set<String> { Set(chips.values).union([fallback, sort, rating, search]) }
}
