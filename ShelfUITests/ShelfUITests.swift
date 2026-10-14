import UIKit
import XCTest

@MainActor final class ShelfUITests: XCTestCase {
  let app = XCUIApplication()
  let remote = XCUIRemote.shared
  private func launch(_ extra: [String] = []) {
    continueAfterFailure = false
    remote.press(.home)
    app.launchArguments = ["--ui-testing", "--mute-playback", "--ui-reset-preferences"] + extra
    app.launch()
    addTeardownBlock { [app] in await MainActor.run { app.terminate() } }
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
  }
  private func screenshot(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  private func wait(_ message: String, timeout: TimeInterval = 30, condition: @escaping () -> Bool)
  {
    let predicate = NSPredicate { _, _ in MainActor.assumeIsolated { condition() } }
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout),
      .completed, message + "\n" + app.debugDescription)
  }
  private var focused: XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
  }
  private func isFocused(_ target: XCUIElement) -> Bool {
    if target.hasFocus { return true }
    // tvOS List focuses its row container, with the action button as a descendant.
    return focused.exists
      && focused.descendants(matching: .any).matching(identifier: target.identifier).firstMatch
        .exists
  }
  private func focus(_ candidate: XCUIElement) {
    XCTAssertTrue(
      candidate.waitForExistence(timeout: 45), "Missing target\n" + app.debugDescription)
    let identifier = candidate.identifier
    if identifier.hasPrefix("chip.") {
      if !focused.exists || !focused.identifier.hasPrefix("chip.") {
        if !app.tabBars.buttons.allElementsBoundByIndex.contains(where: { $0.hasFocus }) {
          remote.press(.menu)
        }
        if app.tabBars.buttons.allElementsBoundByIndex.contains(where: { $0.hasFocus }) {
          remote.press(.down)
        }
        wait("Could not enter chip strip", timeout: 3) {
          self.focused.exists && self.focused.identifier.hasPrefix("chip.")
        }
      }
      let ids = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chip.'"))
        .allElementsBoundByIndex.map(\.identifier)
      let targetIndex = ids.firstIndex(of: identifier)!
      wait("Chip focus must settle", timeout: 3) {
        self.focused.exists && self.focused.identifier.hasPrefix("chip.")
      }
      var index = ids.firstIndex(of: focused.identifier)!
      while index != targetIndex {
        let step = index < targetIndex ? 1 : -1
        remote.press(step > 0 ? .right : .left)
        index += step
        let expected = app.buttons[ids[index]]
        if !expected.hasFocus {
          wait("One navigation key must focus " + ids[index], timeout: 3) { expected.hasFocus }
        }
      }
      return
    }
    let target = app.descendants(matching: candidate.elementType).matching(identifier: identifier)
      .firstMatch
    for _ in 0..<80 {
      if isFocused(target) { return }
      if !focused.exists {
        wait("Native focus must settle before the next key", timeout: 3) { self.focused.exists }
        continue
      }
      let from = focused.frame
      let to = target.frame
      if abs(from.midY - to.midY) > max(20, min(from.height, to.height) / 2) {
        remote.press(to.midY > from.midY ? .down : .up)
      } else {
        remote.press(to.midX > from.midX ? .right : .left)
      }
    }
    XCTFail("Unable to focus \(target.identifier)\n" + app.debugDescription)
  }
  private func select(_ target: XCUIElement) {
    focus(target)
    if target.identifier.hasPrefix("chip.") {
      wait("Focused chip did not select") { target.isSelected }
      wait("Selected chip did not finish loading", timeout: 45) {
        !self.app.staticTexts["browse.metrics"].label.contains("loading=true")
      }
    } else {
      remote.press(.select)
    }
  }
  private func tab(_ name: String) {
    for _ in 0..<3 {
      if app.tabBars.buttons.allElementsBoundByIndex.contains(where: { $0.hasFocus }) { break }
      remote.press(.menu)
    }
    focus(app.tabBars.buttons[name].firstMatch)
    // Tab focus selects its content; do not press Select (which enters the content).
    XCTAssertTrue(app.tabBars.buttons[name].firstMatch.hasFocus)
  }
  private func cards(_ comic: Bool = false) -> XCUIElementQuery {
    app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", comic ? "album.card." : "video.card."))
  }
  private func metric(_ key: String) -> Int {
    let values = app.staticTexts["browse.metrics"].firstMatch.label.split(separator: ";")
    return Int(values.first { $0.hasPrefix(key + "=") }?.split(separator: "=").last ?? "0") ?? 0
  }
  private func ready(_ comic: Bool = false) {
    XCTAssertTrue(cards(comic).firstMatch.waitForExistence(timeout: 45), app.debugDescription)
    XCTAssertTrue(
      cards(comic).matching(NSPredicate(format: "value == %@", "封面已加载")).firstMatch
        .waitForExistence(timeout: 30))
  }
  private func seconds(_ clock: XCUIElement) -> Double {
    Double(clock.label.split(separator: ":").dropFirst().first ?? "0") ?? 0
  }
  private func verifyPlaying(_ name: String) {
    let clock = app.staticTexts["player.progress"]
    XCTAssertTrue(clock.waitForExistence(timeout: 45))
    wait("Muted AVPlayer did not start") {
      clock.label.hasPrefix("playing:") && clock.label.hasSuffix("muted=true")
        && self.seconds(clock) > 0
    }
    let start = seconds(clock)
    wait("AVPlayer did not advance", timeout: 15) { self.seconds(clock) >= start + 2 }
    print("SHELF_PLAYBACK \(name) start=\(start) end=\(seconds(clock)) \(clock.label)")
    screenshot(name)
    remote.press(.menu)
    wait("Menu did not stop playback", timeout: 3) {
      self.app.staticTexts["playback.activity"].label.hasPrefix("active=false")
    }
    let stopped = app.staticTexts["playback.activity"].label
    let stable = expectation(description: "Stopped player stays stopped")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { stable.fulfill() }
    wait(for: [stable], timeout: 2)
    XCTAssertEqual(app.staticTexts["playback.activity"].label, stopped)
  }
  func testChipSymbolsAndStableWidth() {
    for name in FilterSymbols.allNames {
      XCTAssertNotNil(UIImage(systemName: name), "Missing symbol: " + name)
    }
    XCTAssertEqual(FilterSymbols.chip("新分类"), "tag")
    XCTAssertEqual(FilterSymbols.chip("同人誌·漢化"), "character.book.closed.zh")
    launch()
    ready()
    let first = app.buttons["chip.trending"]
    let second = app.buttons["chip.date"]
    let firstSelectedWidth = first.frame.width
    let secondUnselectedWidth = second.frame.width
    press(.down, row: "strip:chip.trending", stage: "symbols-entry")
    remote.press(.right)
    wait("Latest must select without a checkmark") { second.isSelected }
    press(.up, row: "top", stage: "symbols-leave")
    XCTAssertFalse(first.isSelected)
    XCTAssertEqual(first.frame.width, firstSelectedWidth, accuracy: 0.5)
    XCTAssertEqual(second.frame.width, secondUnselectedWidth, accuracy: 0.5)
    screenshot("57-chip-symbol-selection")
  }
  func testHomeScreenIcon() {
    launch()
    ready()
    app.terminate()
    let home = XCUIApplication(bundleIdentifier: "com.apple.HeadBoard")
    XCTAssertTrue(home.wait(for: .runningForeground, timeout: 15))
    let icon = home.icons["inHebi"].firstMatch
    XCTAssertTrue(icon.waitForExistence(timeout: 10))
    XCTAssertTrue(icon.isHittable)
    XCTAssertTrue(icon.hasFocus)
    screenshot("55-home-icon")
  }
  func testMediaGridFiltersAndSearch() {
    launch()
    ready()
    focus(cards().firstMatch)
    screenshot("01-iwara-grid")
    select(app.buttons["chip.trending"])
    let requests = metric("requests")
    remote.press(.right)
    wait("Focus did not select Latest") { self.app.buttons["chip.date"].isSelected }
    wait("Focused chip did not load") { self.metric("requests") > requests }
    ready()
    XCTAssertTrue(app.buttons["chip.date"].hasFocus)
    let firstRow = cards().allElementsBoundByIndex.filter { $0.frame.minY > 0 }.sorted {
      $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY
    }
    focus(firstRow[3])
    remote.press(.up)
    XCTAssertTrue(app.buttons["filter.primary"].hasFocus, app.debugDescription)
    let value = app.buttons["filter.primary"].label
    remote.press(.select)
    wait("Rating cycle did not change") { self.app.buttons["filter.primary"].label != value }
    screenshot("02-iwara-filter-strip")
    tab("Hanime1")
    ready()
    screenshot("03-hanime-grid")
    select(app.buttons["filter.primary"])
    wait("Sheet default option not focused", timeout: 5) {
      self.isFocused(self.app.buttons["option.最新上市"])
    }
    select(app.buttons["option.本週排行"])
    ready()
    select(app.buttons["filter.primary"])
    wait("Sheet current option not focused", timeout: 5) {
      self.isFocused(self.app.buttons["option.本週排行"])
    }
    screenshot("04-sort-current-focus")
    remote.press(.menu)
    select(app.buttons["search.open"])
    XCTAssertTrue(
      app.descendants(matching: .any).matching(identifier: "search.input").firstMatch
        .waitForExistence(timeout: 15), app.debugDescription)
    screenshot("05-search-screen")
    remote.press(.menu)
  }
  func testListReturnTabRetentionAndPagination() {
    launch()
    ready()
    focus(cards().firstMatch)
    let initial = metric("count")
    for _ in 0..<6 { remote.press(.down) }
    wait("Bottom approach did not load another page") { self.metric("count") > initial }
    XCTAssertTrue(focused.identifier.hasPrefix("video.card."))
    let identifier = focused.identifier
    let frame = focused.frame
    let count = metric("count")
    let requests = metric("requests")
    screenshot("06-scrolled-list")
    remote.press(.select)
    XCTAssertTrue(app.buttons["video.play"].waitForExistence(timeout: 30))
    remote.press(.menu)
    wait("Detail return lost card focus") { self.app.buttons[identifier].hasFocus }
    XCTAssertEqual(metric("count"), count)
    XCTAssertEqual(metric("requests"), requests)
    XCTAssertEqual(app.buttons[identifier].frame.minY, frame.minY, accuracy: 4)
    screenshot("07-return-retained")
    remote.press(.menu)
    wait("Menu did not reach selected chip") { self.app.buttons["chip.trending"].hasFocus }
    XCTAssertEqual(metric("count"), count)
    XCTAssertEqual(metric("requests"), requests)
    wait("Menu did not scroll to top") { self.metric("offset") < 2 }
    screenshot("08-pinned-strip-from-menu")
    remote.press(.menu)
    XCTAssertTrue(app.tabBars.buttons.allElementsBoundByIndex.contains { $0.hasFocus })
    remote.press(.down)
    wait("One Down must enter the selected Trends chip", timeout: 3) {
      self.app.buttons["chip.trending"].hasFocus
    }
    tab("Hanime1")
    ready()
    tab("iwara")
    remote.press(.down)
    wait("One Down must enter the selected Trends chip", timeout: 3) {
      self.app.buttons["chip.trending"].hasFocus
    }
    XCTAssertEqual(metric("count"), count)
    XCTAssertEqual(metric("requests"), requests)
    screenshot("09-tab-retained")
  }

  func testIwaraQuickPlaybackAndStop() {
    launch()
    ready()
    select(app.buttons["filter.primary"])
    ready()
    focus(cards().firstMatch)
    let card = focused.identifier
    remote.press(.playPause)
    verifyPlaying("10-iwara-quick-playing")
    wait("Quick playback return lost focus") { self.app.buttons[card].hasFocus }
    remote.press(.select)
    XCTAssertTrue(app.buttons["video.play"].waitForExistence(timeout: 30))
    wait("Play was not default focus after loading") { self.app.buttons["video.play"].hasFocus }
    screenshot("11-iwara-detail")
    if app.buttons["video.description"].exists {
      select(app.buttons["video.description"])
      screenshot("12-description-focus")
    }
  }
  func testHanimeDetailPlaybackAndMetadata() {
    launch()
    tab("Hanime1")
    ready()
    select(app.buttons["chip.Cosplay"])
    ready()
    select(cards().firstMatch)
    XCTAssertTrue(app.buttons["video.play"].waitForExistence(timeout: 30))
    wait("Hanime default focus not Play") { self.app.buttons["video.play"].hasFocus }
    screenshot("13-hanime-detail")
    if app.buttons["video.description"].exists {
      focus(app.buttons["video.description"])
      screenshot("12-description-focus")
      focus(app.buttons["video.play"])
    }
    remote.press(.select)
    verifyPlaying("14-hanime-playing")
    wait("Player close lost Play focus") { self.app.buttons["video.play"].hasFocus }
  }
  func testPlaybackEndsBackAtDetail() {
    launch(["--ui-test-playback-end"])
    tab("Hanime1")
    ready()
    select(app.buttons["chip.Cosplay"])
    ready()
    select(cards().firstMatch)
    XCTAssertTrue(app.buttons["video.play"].waitForExistence(timeout: 30))
    select(app.buttons["video.play"])
    XCTAssertTrue(app.staticTexts["player.progress"].waitForExistence(timeout: 30))
    wait("Actual end-of-item did not return to detail", timeout: 30) {
      self.app.buttons["video.play"].hasFocus
        && self.app.staticTexts["playback.activity"].label.hasPrefix("active=false")
    }
    screenshot("15-playback-ended-detail")
  }
  func testReaderJumpResumeAndSpread() {
    launch()
    tab("漫画")
    ready(true)
    select(app.buttons["chip.3"])
    ready(true)
    focus(cards(true).firstMatch)
    screenshot("16-comic-grid")
    let card = focused.identifier
    remote.press(.playPause)
    let page = app.staticTexts["reader.page"]
    XCTAssertTrue(page.waitForExistence(timeout: 40))
    assertPagePosition(controls: false)
    wait("Reader must hide the Tab bar") {
      !self.app.tabBars.buttons.allElementsBoundByIndex.contains { $0.isHittable }
    }
    screenshot("17-reader-hint")
    remote.press(.left)
    remote.press(.left)
    wait("Reader did not reach page 3") { page.label.hasPrefix("3 /") }
    remote.press(.select)
    wait("Jump strip does not focus current page") { self.app.buttons["reader.jump.3"].hasFocus }
    assertPagePosition(controls: true)
    screenshot("26-reader-toolbar")
    remote.press(.right)
    remote.press(.right)
    remote.press(.select)
    wait("Jump did not select page 5") { page.label.hasPrefix("5 /") }
    remote.press(.left)
    wait("Closed toolbar left canvas unfocused") { page.label.hasPrefix("6 /") }
    screenshot("18-reader-jumped")
    remote.press(.select)
    select(app.buttons["reader.spread"])
    remote.press(.menu)
    wait("Spread did not show pages 6-7") { page.label.hasPrefix("6–7 /") }
    assertJoinedSpread(first: 6, rightToLeft: true)
    // Jump while already in spread mode. Both parities must start at the selected page.
    remote.press(.select)
    remote.press(.left)
    remote.press(.select)
    wait("Spread jump must start at page 5") { page.label.hasPrefix("5–6 /") }
    assertJoinedSpread(first: 5, rightToLeft: true)
    remote.press(.left)
    wait("Spread must advance two pages") { page.label.hasPrefix("7–8 /") }
    remote.press(.right)
    wait("Spread must return two pages") { page.label.hasPrefix("5–6 /") }
    remote.press(.select)
    remote.press(.right)
    remote.press(.select)
    wait("Even jump must start at page 6") { page.label.hasPrefix("6–7 /") }
    screenshot("19-reader-spread")
    remote.press(.menu)
    XCTAssertTrue(app.buttons[card].waitForExistence(timeout: 10))
    wait("Reader navigation did not restore card focus") { self.app.buttons[card].hasFocus }
    let restoredTitle = app.buttons[card].label
    print(
      "SHELF_READER_RETURN hasFocus=\(app.buttons[card].hasFocus) width=\(app.buttons[card].frame.width)"
    )
    remote.press(.select)
    XCTAssertTrue(app.buttons["album.read"].waitForExistence(timeout: 30))
    XCTAssertEqual(
      app.staticTexts["album.title"].label, restoredTitle,
      "Select after return must open the same album")
    wait("Read default focus missing") { self.app.buttons["album.read"].hasFocus }
    XCTAssertTrue(app.buttons["album.read"].label.contains("6"))
    screenshot("20-album-resume-preview")
    remote.press(.select)
    XCTAssertTrue(page.waitForExistence(timeout: 30))
    XCTAssertTrue(page.label.hasPrefix("6–7 /"))
    assertJoinedSpread(first: 6, rightToLeft: true)
    remote.press(.left)
    wait("Resumed spread did not advance") { page.label.hasPrefix("8–9 /") }
    remote.press(.menu)
    wait("Detail did not update latest saved page") {
      self.app.buttons["album.read"].label.contains("8")
    }
  }
  func testSettingsDirection() {
    launch()
    tab("设置")
    select(app.buttons["settings.reading-direction"])
    screenshot("21-settings-direction")
    tab("漫画")
    ready(true)
    select(app.buttons["chip.3"])
    ready(true)
    focus(cards(true).firstMatch)
    remote.press(.playPause)
    let page = app.staticTexts["reader.page"]
    XCTAssertTrue(page.waitForExistence(timeout: 40))
    wait("Reader must hide the Tab bar") {
      !self.app.tabBars.buttons.allElementsBoundByIndex.contains { $0.isHittable }
    }
    remote.press(.right)
    wait("Left-opening direction did not advance on Right") { page.label.hasPrefix("2 /") }
    screenshot("29-left-opening-single")
    remote.press(.select)
    select(app.buttons["reader.spread"])
    remote.press(.menu)
    wait("Left-opening spread did not show pages 2-3") { page.label.hasPrefix("2–3 /") }
    assertJoinedSpread(first: 2, rightToLeft: false)
    remote.press(.right)
    wait("LTR spread must advance two pages") { page.label.hasPrefix("4–5 /") }
    remote.press(.left)
    wait("LTR spread must return two pages") { page.label.hasPrefix("2–3 /") }
    screenshot("30-left-opening-spread")
    remote.press(.menu)
  }
  func testNativeOptionalProbes() {
    launch(["--ui-component-probes"])
    focus(app.buttons["probe.card"])
    screenshot("22-native-card")
    focus(app.buttons["probe.borderless"])
    screenshot("23-native-borderless")
    select(app.buttons["probe.search"])
    XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 15))
    screenshot("24-native-search-scopes")
  }
  func testSearchSubmission() {
    launch()
    ready()
    select(app.buttons["search.open"])
    let field = app.descendants(matching: .any).matching(identifier: "search.input").firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 15))
    select(field)
    app.typeText("MMD")
    let resultButtons = app.otherElements["search.screen"].buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'video.card.'"))
    XCTAssertEqual(resultButtons.count, 0, "Typing alone must not issue search")
    // tvOS' modal keyboard has an explicit completion button below the letter/number rows.
    remote.press(.down)
    remote.press(.down)
    remote.press(.down)
    remote.press(.select)
    XCTAssertTrue(resultButtons.firstMatch.waitForExistence(timeout: 45), app.debugDescription)
    XCTAssertTrue(
      resultButtons.matching(NSPredicate(format: "value == %@", "封面已加载")).firstMatch
        .waitForExistence(timeout: 30))
    screenshot("25-search-results")
    remote.press(.menu)
  }
  func testPlayerInfoPanel() {
    launch()
    tab("Hanime1")
    ready()
    select(app.buttons["chip.Cosplay"])
    ready()
    select(cards().firstMatch)
    XCTAssertTrue(app.buttons["video.play"].waitForExistence(timeout: 30))
    select(app.buttons["video.play"])
    let clock = app.staticTexts["player.progress"]
    XCTAssertTrue(clock.waitForExistence(timeout: 30))
    wait("Info probe playback did not start") { self.seconds(clock) >= 1 }
    remote.press(.playPause)
    remote.press(.down)
    print("SHELF_PLAYER_INFO_TREE\n" + app.debugDescription)
    screenshot("27-player-info-probe")
    remote.press(.menu)
    wait("Info panel did not close", timeout: 8) { !self.app.buttons["From Beginning"].isHittable }
    remote.press(.menu)
    let transition = expectation(description: "Native controls transition")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { transition.fulfill() }
    wait(for: [transition], timeout: 2)
    if app.staticTexts["player.progress"].exists { remote.press(.menu) }
    wait("Info probe failed to stop") {
      self.app.staticTexts["playback.activity"].label.hasPrefix("active=false")
    }
  }

  func testHanimePortraitGrid() {
    launch()
    tab("Hanime1")
    ready()
    select(app.buttons["chip.裏番"])
    ready()
    let first = cards().firstMatch
    XCTAssertEqual(first.frame.width, 320, accuracy: 1)
    XCTAssertEqual(first.frame.height, 480, accuracy: 1)
    XCTAssertEqual(first.frame.height / first.frame.width, 1.5, accuracy: 0.02)
    focus(first)
    screenshot("28-hanime-portrait-grid")
  }

  private func assertPagePosition(controls: Bool) {
    let page = app.staticTexts["reader.page"].frame
    let screen = app.frame
    XCTAssertGreaterThan(page.minX, screen.midX)
    XCTAssertGreaterThanOrEqual(screen.maxX - page.maxX, 32)
    XCTAssertLessThanOrEqual(screen.maxX - page.maxX, 80)
    XCTAssertLessThan(page.height, 50)
    if controls {
      XCTAssertLessThan(page.maxY, app.buttons["reader.spread"].frame.minY)
    } else {
      XCTAssertGreaterThanOrEqual(screen.maxY - page.maxY, 20)
      XCTAssertLessThanOrEqual(screen.maxY - page.maxY, 64)
    }
  }

  private func assertJoinedSpread(first: Int, rightToLeft: Bool) {
    let left = app.otherElements["reader.image.\(rightToLeft ? first + 1 : first)"]
    let right = app.otherElements["reader.image.\(rightToLeft ? first : first + 1)"]
    wait("Both spread images must finish loading", timeout: 45) {
      left.images["image.loaded"].exists && right.images["image.loaded"].exists
    }
    let a = left.images["image.loaded"].frame
    let b = right.images["image.loaded"].frame
    XCTAssertEqual(a.maxX, b.minX, accuracy: 1, "The inner image edges must join without a gap")
    XCTAssertEqual(a.minY, b.minY, accuracy: 1)
    XCTAssertEqual(a.height, b.height, accuracy: 1)
    XCTAssertEqual(a.union(b).midX, app.frame.midX, accuracy: 1)
    XCTAssertEqual(a.union(b).midY, app.frame.midY, accuracy: 1)
    print("JOINED_SPREAD first=\(first) rtl=\(rightToLeft) left=\(a) right=\(b)")
  }

  func testReaderBottomRowDownClosesControls() {
    launch()
    tab("漫画")
    ready(true)
    select(app.buttons["chip.3"])
    ready(true)
    focus(cards(true).firstMatch)
    remote.press(.playPause)
    let page = app.staticTexts["reader.page"]
    XCTAssertTrue(page.waitForExistence(timeout: 40))
    remote.press(.left)
    remote.press(.left)
    for id in ["next", "previous", "spread", "retry", "resume", "close"] {
      remote.press(.select)
      wait("Opening controls must focus current thumbnail") {
        self.app.buttons["reader.jump.3"].hasFocus
      }
      assertPagePosition(controls: true)
      let button = app.buttons["reader." + id]
      focus(button)
      XCTAssertTrue(button.hasFocus)
      remote.press(.down)
      wait("Bottom row Down must dismiss controls from \(id)") {
        !self.app.buttons["reader.spread"].exists
      }
      XCTAssertTrue(page.label.hasPrefix("3 /"))
      assertPagePosition(controls: false)
    }
    remote.press(.left)
    wait("Dismissed panel must restore canvas input") { page.label.hasPrefix("4 /") }
  }

  func testFocusedGridTitlesAndAspectRatios() {
    launch()
    for (name, chip, columns, ratio) in [
      ("iwara", "trending", 4, CGFloat(16) / 9),
      ("Hanime1", "裏番", 5, CGFloat(2) / 3),
      ("漫画", "", 5, CGFloat(3) / 4),
    ] {
      if name != "iwara" { tab(name) }
      ready(name == "漫画")
      select(app.buttons["chip." + chip])
      ready(name == "漫画")
      let items = cards(name == "漫画").allElementsBoundByIndex
      XCTAssertGreaterThanOrEqual(items.count, columns * 2)
      let first = items[0]
      let firstID = first.identifier.components(separatedBy: ".card.")[1]
      XCTAssertEqual(first.frame.width, columns == 4 ? 404 : 320, accuracy: 1)
      XCTAssertEqual(first.frame.width / first.frame.height, ratio, accuracy: 0.01)
      XCTAssertEqual(
        first.frame.minX, app.staticTexts["entry.title." + firstID].frame.minX, accuracy: 1)
      for card in [first, items[columns]] {
        focus(card)
        let id = card.identifier.components(separatedBy: ".card.")[1]
        let title = app.staticTexts["entry.title." + id]
        XCTAssertTrue(title.exists)
        wait("Focused cover and title must not intersect") {
          !card.frame.intersects(title.frame) && card.frame.maxY <= title.frame.minY
        }
        XCTAssertTrue(card.hasFocus)
        XCTAssertEqual(card.frame.width / card.frame.height, ratio, accuracy: 0.01)
        print(
          "CARD_TITLE \(name) cover=\(card.frame) title=\(title.frame) gap=\(title.frame.minY - card.frame.maxY)"
        )
      }
    }
  }

  func testFilterEntryAndSingleStepNavigation() {
    launch()
    ready()
    XCTAssertTrue(app.buttons["chip.trending"].isSelected)
    XCTAssertTrue(app.tabBars.buttons["iwara"].hasFocus)
    remote.press(.down)
    wait("One Down must enter the selected Trends chip", timeout: 3) {
      self.app.buttons["chip.trending"].hasFocus
    }
    remote.press(.down)
    XCTAssertTrue(focused.identifier.hasPrefix("video.card."), app.debugDescription)
    remote.press(.up)
    wait("One Down must enter the selected Trends chip", timeout: 3) {
      self.app.buttons["chip.trending"].hasFocus
    }
    for name in ["Hanime1", "漫画"] {
      tab(name)
      ready(name == "漫画")
      remote.press(.down)
      wait("One Down must enter first selected chip", timeout: 3) {
        self.app.buttons["chip."].hasFocus
      }
      if name == "漫画" { screenshot("41-comic-flat-categories") }
      let chips = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chip.'"))
        .allElementsBoundByIndex
      if name == "Hanime1" {
        XCTAssertEqual(chips.count, 11)
      } else {
        XCTAssertEqual(chips.count, 21, "Latest plus all 20 parent/child categories")
      }
      for index in 1..<chips.count {
        remote.press(.right)
        XCTAssertTrue(
          chips[index].hasFocus, "Right must move one: \(index), actual \(focused.identifier)")
        if index.isMultiple(of: 3) {
          let segment = ["one", "two", "three", "four", "five", "six"][index / 3 - 1]
          screenshot((name == "漫画" ? "59-comic-symbols-" : "58-hanime-symbols-") + segment)
        }
      }
      let last = chips.last!
      wait("Last chip not selected") { last.isSelected }
      let edge = app.buttons[name == "漫画" ? "search.open" : "filter.primary"].frame.minX
      XCTAssertGreaterThanOrEqual(last.frame.minX, 70)
      XCTAssertLessThanOrEqual(last.frame.maxX, edge - 10, "Last chip must be fully visible")
      screenshot(name == "漫画" ? "35-comic-strip-end" : "34-hanime-strip-end")
      remote.press(.right)
      XCTAssertTrue(
        app.buttons[name == "漫画" ? "search.open" : "filter.primary"].hasFocus, app.debugDescription)
      let settledCalls = metric("requests")
      remote.press(.menu)
      XCTAssertTrue(app.tabBars.buttons.allElementsBoundByIndex.contains { $0.hasFocus })
      remote.press(.down)
      wait("Tab Down must restore selected end chip", timeout: 3) { last.hasFocus }
      XCTAssertEqual(metric("requests"), settledCalls)
      screenshot(name == "漫画" ? "40-comic-selected-entry" : "39-hanime-selected-entry")
      remote.press(.right)
      remote.press(.left)
      XCTAssertTrue(last.hasFocus)
      for index in stride(from: chips.count - 2, through: 0, by: -1) {
        remote.press(.left)
        XCTAssertTrue(
          chips[index].hasFocus, "Left must move one: \(index), actual \(focused.identifier)")
      }
      wait("First chip not selected") { chips[0].isSelected }
      ready(name == "漫画")
    }
  }
  func testFocusDebounceAndThreePages() {
    launch()
    ready()
    remote.press(.down)
    let requests = metric("requests")
    remote.press(.right, forDuration: 0.01)
    remote.press(.right, forDuration: 0.01)
    remote.press(.right, forDuration: 0.01)
    wait("Final chip must select Views") { self.app.buttons["chip.views"].isSelected }
    wait("Each settled focus should load once") { self.metric("requests") == requests + 3 }
    ready()
    XCTAssertTrue(app.buttons["chip.views"].hasFocus)
    let first = cards().firstMatch.identifier
    remote.press(.down)
    XCTAssertTrue(focused.identifier.hasPrefix("video.card."), app.debugDescription)
    remote.press(.up)
    XCTAssertTrue(app.buttons["chip.views"].hasFocus)
    XCTAssertEqual(cards().firstMatch.identifier, first)
    XCTAssertEqual(metric("requests"), requests + 3)
    remote.press(.down)
    let pageSize = metric("count")
    for _ in 0..<80 {
      remote.press(.down)
      if metric("index") >= pageSize * 3 - 4 { break }
    }
    XCTAssertGreaterThanOrEqual(metric("count"), pageSize * 3)
    XCTAssertGreaterThanOrEqual(
      metric("index"), pageSize * 3 - 4, "Focus must traverse the third page, not just prefetch it")
    print("THREE_PAGES focusIndex=\(metric("index")) count=\(metric("count"))")
    XCTAssertTrue(focused.identifier.hasPrefix("video.card."))
    screenshot("36-three-page-pagination")
    let total = metric("count")
    let calls = metric("requests")
    remote.press(.menu)
    wait("Menu must reach selected chip") { self.app.buttons["chip.views"].hasFocus }
    wait("Menu must scroll to top") { self.metric("offset") < 2 }
    XCTAssertEqual(metric("count"), total)
    XCTAssertEqual(metric("requests"), calls)
    screenshot("37-menu-to-top")
    remote.press(.menu)
    XCTAssertTrue(app.tabBars.buttons.allElementsBoundByIndex.contains { $0.hasFocus })
    remote.press(.down)
    XCTAssertTrue(app.buttons["chip.views"].hasFocus)
    select(app.buttons["filter.primary"])
    let rating = app.buttons["filter.primary"].label
    app.terminate()
    app.launchArguments = ["--ui-testing", "--mute-playback"]
    app.launch()
    ready()
    XCTAssertTrue(app.buttons["chip.trending"].isSelected, "Cold launch must not restore Views")
    XCTAssertEqual(
      app.buttons["filter.primary"].label, rating, "Rating must persist across cold launches")
  }

  func testRapidFocusDebounceIntegration() {
    launch(["--ui-fast-focus"])
    ready()
    remote.press(.down)
    wait("One Down must enter the selected Trends chip", timeout: 3) {
      self.app.buttons["chip.trending"].hasFocus
    }
    let initial = metric("requests")
    let original = cards().firstMatch.identifier
    remote.press(.playPause)
    wait("100ms focus burst did not settle on Views") { self.app.buttons["chip.views"].isSelected }
    wait("Fast intermediate chips must not request") { self.metric("requests") == initial + 1 }
    ready()
    XCTAssertTrue(app.buttons["chip.views"].hasFocus)
    XCTAssertNotEqual(cards().firstMatch.identifier, original)
    XCTAssertTrue(app.staticTexts["browse.metrics"].label.contains("key=views|"))
    print("SYNTHETIC_FOCUS_BURST 100ms updates; one request for final chip only")
    screenshot("38-focus-debounce")
  }

  func testHanimeSearchKeepsCategory() {
    launch()
    tab("Hanime1")
    ready()
    select(app.buttons["chip.MMD"])
    ready()
    focus(cards().firstMatch)
    remote.press(.right)
    remote.press(.right)
    remote.press(.right)
    remote.press(.up)
    XCTAssertTrue(app.buttons["filter.primary"].hasFocus)
    remote.press(.right)
    select(app.buttons["search.open"])
    let field = app.descendants(matching: .any).matching(identifier: "search.input").firstMatch
    select(field)
    app.typeText("MMD")
    remote.press(.down)
    remote.press(.down)
    remote.press(.down)
    remote.press(.select)
    let screen = app.otherElements["search.screen"]
    XCTAssertTrue(
      screen.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'video.card.'")).firstMatch
        .waitForExistence(timeout: 45))
    XCTAssertTrue(screen.staticTexts["browse.metrics"].label.contains("selection=MMD;"))
    screenshot("42-hanime-scoped-search")
  }

  private func currentRow() -> String {
    let item = app.buttons.matching(NSPredicate(format: "hasFocus == true")).firstMatch
    guard item.exists else { return "none" }
    let id = item.identifier
    if ["play.rectangle", "film", "books.vertical", "gearshape"].contains(id) { return "top" }
    if id.hasPrefix("chip.") || id == "filter.primary" || id == "search.open" {
      return "strip:" + id
    }
    if id.hasPrefix("video.card.") || id.hasPrefix("album.card.") { return "grid:" + id }
    return id
  }
  private func press(_ key: XCUIRemote.Button, row: String, stage: String) {
    remote.press(key)
    wait(stage + " must focus " + row, timeout: 3) { self.currentRow().hasPrefix(row) }
    print("ROW \(stage)=\(currentRow())")
  }
  private func directionalRows(normal: Bool) {
    if normal {
      continueAfterFailure = false
      remote.press(.home)
      app.launchArguments = []
      app.launch()
      addTeardownBlock { [app] in await MainActor.run { app.terminate() } }
    } else {
      launch()
    }
    XCTAssertTrue(app.buttons["chip.trending"].waitForExistence(timeout: 30))
    for name in ["iwara", "Hanime1", "漫画"] {
      if name != "iwara" { tab(name) }
      ready(name == "漫画")
      press(.down, row: "strip:", stage: name + " top-down")
      XCTAssertTrue(focused.isSelected)
      press(.down, row: "grid:", stage: name + " strip-down")
      XCTAssertEqual(
        focused.frame.midY, cards(name == "漫画").firstMatch.frame.midY, accuracy: 15,
        "Strip Down must enter the first row")
      for _ in 0..<3 { press(.down, row: "grid:", stage: name + " grid-down") }
      for _ in 0..<3 { press(.up, row: "grid:", stage: name + " grid-up") }
      press(.up, row: "strip:", stage: name + " first-row-up")
      XCTAssertTrue(
        focused.isSelected || focused.identifier == "filter.primary"
          || focused.identifier == "search.open")
      press(.up, row: "top", stage: name + " strip-up")
      press(.down, row: "strip:", stage: name + " reentry")
      press(.down, row: "grid:", stage: name + " loaded-down")
      remote.press(.select)
      XCTAssertTrue(
        app.buttons[name == "漫画" ? "album.read" : "video.play"].waitForExistence(timeout: 30))
      press(.menu, row: "grid:", stage: name + " detail-return")
      press(.up, row: "strip:", stage: name + " detail-strip")
      press(.up, row: "top", stage: name + " detail-top")
      press(.down, row: "strip:", stage: name + " after-detail-entry")
      remote.press(.right)
      remote.press(.down)
      XCTAssertTrue(
        currentRow().hasPrefix("strip:") || currentRow().hasPrefix("grid:"),
        "Loading Down must not reverse: " + currentRow())
      ready(name == "漫画")
      if currentRow().hasPrefix("strip:") {
        press(.down, row: "grid:", stage: name + " load-completed")
      }
      screenshot(
        (normal ? "52-normal-" : "53-test-")
          + (name == "漫画" ? "comic" : name == "Hanime1" ? "hanime" : "iwara"))
      press(.up, row: "strip:", stage: name + " changed-category-up")
      press(.up, row: "top", stage: name + " changed-category-top")
    }
  }
  func testSingleUpdateStripEntry() {
    launch()
    for (name, id) in [("iwara", "likes"), ("Hanime1", "裏番"), ("漫画", "5")] {
      if name != "iwara" { tab(name) }
      ready(name == "漫画")
      let selected = app.buttons["chip." + id]
      select(selected)
      press(.up, row: "top", stage: name + " entry-top")
      func updates() -> Int {
        Int((selected.value as? String ?? "").split(separator: "=").last ?? "") ?? -1
      }
      let topCount = updates()
      XCTAssertGreaterThanOrEqual(topCount, 0)
      press(.down, row: "strip:chip." + id, stage: name + " single-top-entry")
      XCTAssertEqual(updates(), topCount + 1, "Entry must not land on an intermediate chip")
      press(.down, row: "grid:", stage: name + " entry-grid")
      for _ in 0..<4 { remote.press(.left) }
      XCTAssertTrue(currentRow().hasPrefix("grid:"))
      XCTAssertGreaterThan(selected.frame.midX, focused.frame.midX + 100)
      let gridCount = updates()
      press(.up, row: "strip:chip." + id, stage: name + " single-grid-entry")
      XCTAssertEqual(updates(), gridCount + 1, "Grid entry must be a single native update")
      screenshot(
        "54-direct-entry-" + (name == "漫画" ? "comic" : name == "Hanime1" ? "hanime" : "iwara"))
    }
  }
  func testNormalDirectionalRows() { directionalRows(normal: true) }
  func testTestingDirectionalRows() { directionalRows(normal: false) }
  func testDirectionalTiming() {
    launch(["--ui-focus-before-down", "--ui-slow-list"])
    ready()
    for name in ["iwara", "Hanime1", "漫画"] {
      if name != "iwara" {
        tab(name)
        ready(name == "漫画")
      }
      press(.down, row: "strip:", stage: name + " timing-entry")
      remote.press(.playPause)
      remote.press(.down)
      XCTAssertTrue(currentRow().hasPrefix("grid:") || currentRow().hasPrefix("strip:"))
      print("EARLY_DOWN " + name + " " + currentRow())
      if currentRow().hasPrefix("grid:") {
        press(.menu, row: "strip:", stage: name + " timing-reset")
      }
      remote.press(.right)
      wait("Controlled loading phase", timeout: 8) {
        self.app.staticTexts["browse.metrics"].label.contains("loading=true")
      }
      press(.down, row: "strip:", stage: name + " loading-down")
      wait("Load completion", timeout: 20) {
        self.app.staticTexts["browse.metrics"].label.contains("loading=false")
      }
      press(.down, row: "grid:", stage: name + " just-loaded-down")
      for _ in 0..<3 { press(.down, row: "grid:", stage: name + " continuous-down") }
      for _ in 0..<3 { remote.press(.down, forDuration: 0.01) }
      wait("Rapid Down must remain in grid", timeout: 3) { self.currentRow().hasPrefix("grid:") }
      remote.press(.menu)
      press(.menu, row: "top", stage: name + " timing-menu-top")
    }
  }
}
