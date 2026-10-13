import XCTest

@MainActor final class ShelfUITests: XCTestCase {
    let app = XCUIApplication()
    let remote = XCUIRemote.shared
    private func launch(_ extra: [String] = []) {
        continueAfterFailure = false
        app.launchArguments = ["--ui-testing", "--mute-playback", "--ui-reset-preferences"] + extra
        app.launch()
        addTeardownBlock { [app] in await MainActor.run { app.terminate() } }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func wait(_ message: String, timeout: TimeInterval = 30, condition: @escaping () -> Bool) {
        let predicate = NSPredicate { _, _ in MainActor.assumeIsolated { condition() } }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout), .completed, message)
    }
    private var focused: XCUIElement { app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch }
    private func focus(_ target: XCUIElement) {
        XCTAssertTrue(target.waitForExistence(timeout: 45), "Missing target\n" + app.debugDescription)
        for _ in 0..<24 {
            if target.hasFocus { return }
            guard focused.exists else { remote.press(.down); continue }
            let from = focused.frame, to = target.frame
            if abs(from.midY - to.midY) > max(20, min(from.height, to.height) / 2) { remote.press(to.midY > from.midY ? .down : .up) }
            else { remote.press(to.midX > from.midX ? .right : .left) }
        }
        XCTFail("Unable to focus \(target.identifier)\n" + app.debugDescription)
    }
    private func select(_ target: XCUIElement) { focus(target); remote.press(.select) }
    private func tab(_ name: String) { remote.press(.up); select(app.tabBars.buttons[name].firstMatch) }
    private func cards(_ comic: Bool = false) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", comic ? "album.card." : "video.card."))
    }
    private func metric(_ key: String) -> Int {
        let values = app.staticTexts["browse.metrics"].firstMatch.label.split(separator: ";")
        return Int(values.first { $0.hasPrefix(key + "=") }?.split(separator: "=").last ?? "0") ?? 0
    }
    private func ready(_ comic: Bool = false) {
        XCTAssertTrue(cards(comic).firstMatch.waitForExistence(timeout: 45))
        XCTAssertTrue(app.images["image.loaded"].firstMatch.waitForExistence(timeout: 30))
    }
    private func seconds(_ clock: XCUIElement) -> Double { Double(clock.label.split(separator: ":").dropFirst().first ?? "0") ?? 0 }
    private func verifyPlaying(_ name: String) {
        let clock = app.staticTexts["player.progress"]
        XCTAssertTrue(clock.waitForExistence(timeout: 45))
        wait("Muted AVPlayer did not start") { clock.label.hasPrefix("playing:") && clock.label.hasSuffix("muted=true") && self.seconds(clock) > 0 }
        let start = seconds(clock)
        wait("AVPlayer did not advance", timeout: 15) { self.seconds(clock) >= start + 2 }
        print("SHELF_PLAYBACK \(name) start=\(start) end=\(seconds(clock)) \(clock.label)")
        screenshot(name)
        remote.press(.menu)
        wait("Menu did not stop playback") { self.app.staticTexts["playback.activity"].label.hasPrefix("active=false") }
        let stopped = app.staticTexts["playback.activity"].label
        let stable = expectation(description: "Stopped player stays stopped")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { stable.fulfill() }
        wait(for: [stable], timeout: 2)
        XCTAssertEqual(app.staticTexts["playback.activity"].label, stopped)
    }
    func testMediaGridFiltersAndSearch() {
        launch(); ready()
        focus(cards().firstMatch)
        screenshot("01-iwara-grid")
        let visibleRows = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'entry.'")).allElementsBoundByIndex.filter { $0.frame.minY >= 0 && $0.frame.maxY <= 1080 }
        XCTAssertGreaterThanOrEqual(visibleRows.count, 8, "Two complete landscape rows expected")
        focus(app.buttons["chip.date"])
        let requests = metric("requests")
        remote.press(.right); remote.press(.right)
        XCTAssertEqual(metric("requests"), requests, "Moving focus must not load")
        let selected = focused.identifier
        remote.press(.select)
        wait("Selecting chip did not load") { self.metric("requests") > requests }
        ready()
        XCTAssertTrue(app.buttons[selected].isSelected)
        XCTAssertTrue(app.buttons[selected].hasFocus)
        let firstRow = cards().allElementsBoundByIndex.filter { $0.frame.minY > 0 }.sorted { $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY }
        focus(firstRow[3]); remote.press(.up)
        XCTAssertTrue(app.buttons["filter.primary"].hasFocus, app.debugDescription)
        let value = app.buttons["filter.primary"].label
        remote.press(.select)
        wait("Rating cycle did not change") { self.app.buttons["filter.primary"].label != value }
        screenshot("02-iwara-filter-strip")
        tab("Hanime1"); ready()
        screenshot("03-hanime-grid")
        select(app.buttons["filter.primary"])
        XCTAssertTrue(app.buttons["option.最新上市"].hasFocus)
        select(app.buttons["option.本週排行"])
        ready(); select(app.buttons["filter.primary"])
        XCTAssertTrue(app.buttons["option.本週排行"].hasFocus)
        screenshot("04-sort-current-focus")
        remote.press(.menu)
        select(app.buttons["search.open"])
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        screenshot("05-search-screen")
        remote.press(.menu)
    }
    func testListReturnTabRetentionAndPagination() {
        launch(); ready()
        focus(cards().firstMatch)
        let initial = metric("count")
        for _ in 0..<6 { remote.press(.down) }
        wait("Bottom approach did not load another page") { self.metric("count") > initial }
        XCTAssertTrue(focused.identifier.hasPrefix("video.card."))
        let identifier = focused.identifier, frame = focused.frame, count = metric("count"), requests = metric("requests")
        screenshot("06-scrolled-list")
        remote.press(.select)
        XCTAssertTrue(app.buttons["video.play"].waitForExistence(timeout: 30))
        remote.press(.menu)
        wait("Detail return lost card focus") { self.app.buttons[identifier].hasFocus }
        XCTAssertEqual(metric("count"), count); XCTAssertEqual(metric("requests"), requests)
        XCTAssertEqual(app.buttons[identifier].frame.minY, frame.minY, accuracy: 4)
        screenshot("07-return-retained")
        remote.press(.menu)
        wait("Root Menu did not focus Tab bar") { self.app.tabBars.buttons.allElementsBoundByIndex.contains { $0.hasFocus } }
        remote.press(.down)
        XCTAssertTrue(focused.identifier.hasPrefix("chip.") || focused.identifier == "filter.primary" || focused.identifier == "search.open")
        screenshot("08-pinned-strip-from-menu")
        focus(app.buttons[identifier])
        tab("Hanime1"); ready(); tab("iwara")
        wait("Tab return lost card focus") { self.app.buttons[identifier].hasFocus }
        XCTAssertEqual(metric("count"), count); XCTAssertEqual(metric("requests"), requests)
        screenshot("09-tab-retained")
    }
    func testIwaraQuickPlaybackAndStop() {
        launch(); ready(); focus(cards().firstMatch)
        let card = focused.identifier
        remote.press(.playPause)
        verifyPlaying("10-iwara-quick-playing")
        wait("Quick playback return lost focus") { self.app.buttons[card].hasFocus }
        remote.press(.select)
        XCTAssertTrue(app.buttons["video.play"].waitForExistence(timeout: 30))
        wait("Play was not default focus after loading") { self.app.buttons["video.play"].hasFocus }
        screenshot("11-iwara-detail")
        XCTAssertTrue(app.buttons["video.description"].exists)
        select(app.buttons["video.description"])
        screenshot("12-description-focus")
    }
    func testHanimeDetailPlaybackAndMetadata() {
        launch(); tab("Hanime1"); ready(); select(cards().firstMatch)
        XCTAssertTrue(app.buttons["video.play"].waitForExistence(timeout: 30))
        wait("Hanime default focus not Play") { self.app.buttons["video.play"].hasFocus }
        screenshot("13-hanime-detail")
        remote.press(.select)
        verifyPlaying("14-hanime-playing")
        wait("Player close lost Play focus") { self.app.buttons["video.play"].hasFocus }
    }
    func testPlaybackEndsBackAtDetail() {
        launch(["--ui-test-playback-end"]); tab("Hanime1"); ready(); select(cards().firstMatch)
        XCTAssertTrue(app.buttons["video.play"].waitForExistence(timeout: 30)); select(app.buttons["video.play"])
        XCTAssertTrue(app.staticTexts["player.progress"].waitForExistence(timeout: 30))
        wait("Actual end-of-item did not return to detail", timeout: 30) { self.app.buttons["video.play"].hasFocus && self.app.staticTexts["playback.activity"].label.hasPrefix("active=false") }
        screenshot("15-playback-ended-detail")
    }
    func testReaderJumpResumeAndSpread() {
        launch(); tab("漫画"); ready(true); focus(cards(true).firstMatch)
        screenshot("16-comic-grid")
        let card = focused.identifier
        remote.press(.playPause)
        let page = app.staticTexts["reader.page"]
        XCTAssertTrue(page.waitForExistence(timeout: 40))
        screenshot("17-reader-hint")
        remote.press(.left); remote.press(.left)
        wait("Reader did not reach page 3") { page.label.hasPrefix("3 /") }
        remote.press(.select)
        wait("Jump strip does not focus current page") { self.app.buttons["reader.jump.3"].hasFocus }
        remote.press(.right); remote.press(.right); remote.press(.select)
        wait("Jump did not select page 5") { page.label.hasPrefix("5 /") }
        remote.press(.left)
        wait("Closed toolbar left canvas unfocused") { page.label.hasPrefix("6 /") }
        screenshot("18-reader-jumped")
        remote.press(.select); select(app.buttons["reader.spread"]); remote.press(.menu)
        wait("Spread did not show pages 6-7") { page.label.hasPrefix("6–7 /") }
        screenshot("19-reader-spread")
        remote.press(.menu)
        wait("Quick reader did not restore card") { self.app.buttons[card].hasFocus }
        remote.press(.select)
        XCTAssertTrue(app.buttons["album.read"].waitForExistence(timeout: 30))
        wait("Read default focus missing") { self.app.buttons["album.read"].hasFocus }
        XCTAssertTrue(app.buttons["album.read"].label.contains("6"))
        screenshot("20-album-resume-preview")
        remote.press(.select)
        XCTAssertTrue(page.waitForExistence(timeout: 30)); XCTAssertTrue(page.label.hasPrefix("6–7 /"))
        remote.press(.menu)
    }
    func testSettingsDirection() {
        launch(); tab("设置"); select(app.buttons["settings.reading-direction"])
        screenshot("21-settings-direction")
        tab("漫画"); ready(true); focus(cards(true).firstMatch); remote.press(.playPause)
        let page = app.staticTexts["reader.page"]
        XCTAssertTrue(page.waitForExistence(timeout: 40)); remote.press(.right)
        wait("Left-opening direction did not advance on Right") { page.label.hasPrefix("2 /") }
        remote.press(.menu)
    }
    func testNativeOptionalProbes() {
        launch(["--ui-component-probes"])
        focus(app.buttons["probe.card"]); screenshot("22-native-card")
        focus(app.buttons["probe.borderless"]); screenshot("23-native-borderless")
        select(app.buttons["probe.search"])
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 15))
        screenshot("24-native-search-scopes")
    }
}
