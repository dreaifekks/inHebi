import XCTest

@MainActor final class ShelfUITests: XCTestCase {
    let app = XCUIApplication()
    let remote = XCUIRemote.shared

    private func launch() {
        continueAfterFailure = false
        app.launchArguments = ["--ui-testing", "--mute-playback"]
        app.launch()
        addTeardownBlock { [app] in
            await MainActor.run { app.terminate() }
        }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func wait(_ message: String, timeout: TimeInterval = 30, condition: @escaping () -> Bool) {
        let predicate = NSPredicate { _, _ in MainActor.assumeIsolated { condition() } }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout), .completed, message)
    }
    /// Reach a visible element with real directional presses rather than invoking an element action.
    private func focus(_ target: XCUIElement) {
        XCTAssertTrue(target.waitForExistence(timeout: 40), "Missing focus target\n" + app.debugDescription)
        for _ in 0..<18 {
            if target.hasFocus { return }
            let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
            guard focused.exists else { remote.press(.down); continue }
            let from = focused.frame, to = target.frame
            if abs(from.midY - to.midY) > max(20, min(from.height, to.height) / 2) {
                remote.press(to.midY > from.midY ? .down : .up)
            } else { remote.press(to.midX > from.midX ? .right : .left) }
        }
        XCTFail("Unable to focus \(target.identifier)\n" + app.debugDescription)
    }
    private func select(_ target: XCUIElement) {
        focus(target)
        remote.press(.select)
    }
    private func tab(_ name: String) {
        // Root tab bar may auto-hide while content has focus; Up reveals it.
        remote.press(.up)
        select(app.buttons[name].firstMatch)
    }
    private func waitForCover() {
        XCTAssertTrue(app.images["image.loaded"].firstMatch.waitForExistence(timeout: 30))
    }
    func testTabsAndSettings() {
        launch()
        XCTAssertTrue(app.buttons["video.card"].firstMatch.waitForExistence(timeout: 45))
        focus(app.buttons["video.card"].firstMatch)
        waitForCover()
        screenshot("01-home-iwara")
        tab("Hanime1")
        XCTAssertTrue(app.buttons["video.card"].firstMatch.waitForExistence(timeout: 45))
        focus(app.buttons["video.card"].firstMatch)
        waitForCover()
        screenshot("02-hanime-list")
        select(app.buttons["filter.分类"])
        XCTAssertTrue(app.buttons["Motion Anime"].waitForExistence(timeout: 10))
        screenshot("12-hanime-categories")
        remote.press(.menu)
        tab("漫画")
        XCTAssertTrue(app.buttons["album.card"].firstMatch.waitForExistence(timeout: 45))
        focus(app.buttons["album.card"].firstMatch)
        waitForCover()
        screenshot("03-comic-list")
        tab("设置")
        XCTAssertTrue(app.staticTexts["settings.title"].waitForExistence(timeout: 10))
        screenshot("04-settings")
        tab("iwara")
    }
    func testIwaraDetail() {
        launch()
        select(app.buttons["video.card"].firstMatch)
        XCTAssertTrue(app.staticTexts["video.title"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["video.play"].waitForExistence(timeout: 30))
        focus(app.buttons["video.play"])
        waitForCover()
        screenshot("05-iwara-detail")
        remote.press(.menu)
    }
    func testHanimePlayback() {
        launch()
        tab("Hanime1")
        select(app.buttons["video.card"].firstMatch)
        XCTAssertTrue(app.buttons["video.play"].waitForExistence(timeout: 30))
        focus(app.buttons["video.play"])
        waitForCover()
        screenshot("06-hanime-detail")
        remote.press(.select)
        let clock = app.staticTexts["player.progress"]
        XCTAssertTrue(clock.waitForExistence(timeout: 30))
        wait("AVPlayer did not start muted playback") {
            clock.label.hasPrefix("playing:") && clock.label.hasSuffix("muted=true") && self.seconds(clock) > 0
        }
        let start = seconds(clock)
        wait("AVPlayer time did not advance", timeout: 15) { self.seconds(clock) >= start + 2 }
        print("SHELF_PLAYBACK_PROGRESS start=\(start) end=\(seconds(clock)) state=\(clock.label)")
        screenshot("07-hanime-playing")
        // Terminate immediately after the few-second sample, then return to the home screen.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["video.card"].firstMatch.waitForExistence(timeout: 45))
    }
    private func seconds(_ clock: XCUIElement) -> Double {
        Double(clock.label.split(separator: ":").dropFirst().first ?? "0") ?? 0
    }
    func testComicReader() {
        launch()
        tab("漫画")
        select(app.buttons["album.card"].firstMatch)
        XCTAssertTrue(app.buttons["album.read"].waitForExistence(timeout: 30))
        focus(app.buttons["album.read"])
        waitForCover()
        screenshot("08-album-detail")
        remote.press(.select)
        let page = app.staticTexts["reader.page"]
        XCTAssertTrue(page.waitForExistence(timeout: 40))
        waitForCover()
        screenshot("09-reader-single")
        let initial = page.label
        remote.press(.left)
        wait("Reader did not advance") { page.label != initial }
        remote.press(.left)
        wait("Reader did not reach page three") { page.label.hasPrefix("3 /") }
        waitForCover()
        screenshot("10-reader-page-three")
        remote.press(.select)
        select(app.buttons["reader.spread"])
        wait("Spread mode did not activate") { page.label.hasPrefix("3–4 /") }
        remote.press(.menu)
        let canvas = app.descendants(matching: .any).matching(identifier: "reader.canvas").firstMatch
        wait("Both spread images did not load") { canvas.images.matching(identifier: "image.loaded").count == 2 }
        screenshot("11-reader-spread")
        remote.press(.menu)
        XCTAssertTrue(app.buttons["album.read"].waitForExistence(timeout: 15))
    }
}
