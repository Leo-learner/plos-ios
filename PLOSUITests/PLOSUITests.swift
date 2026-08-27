import XCTest

/// L1 walkthrough as automated UI tests (the acceptance report's remaining manual item).
/// Each test drives the real app on a simulator and attaches screenshots, so a visual
/// regression — like content colliding with the floating tab bar — fails or is visible.
///
/// Determinism comes from launch arguments: `-plosResetStore` clears persisted data and
/// `-plosToday` pins the day, so a run on a rest day still exercises the study-day path.
final class PLOSUITests: XCTestCase {

    /// 2026-08-27 is day 27 → (27−1) % 7 = 5 … wait: 26 % 7 = 5 ≥ 5 → rhythm rest.
    /// Day 26 → 25 % 7 = 4 < 5 → study day. Use that for the study-day flows.
    private let studyDay = "2026-08-26"
    private let restDay = "2026-08-28"      // 27 % 7 = 6 → rhythm rest

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(today: String, reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-plosToday", today, "-plosSkipNotificationPrompt"]
        if reset { args.append("-plosResetStore") }
        app.launchArguments = args
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // SwiftUI composes multi-line controls into one element whose label joins every
    // child string ("高能, 状态很好，可以多推进一点"), so match on a prefix, not equality.
    private func button(_ app: XCUIApplication, startingWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func text(_ app: XCUIApplication, containing needle: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    /// Replace a text field's pre-filled value (单位/总量 ship with defaults).
    private func replace(_ field: XCUIElement, with value: String) {
        field.tap()
        if let existing = field.value as? String, !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(value)
    }

    // MARK: - Goal creation helper

    /// Adds one goal through the real form (月计划 → 添加目标 → fill → 添加).
    private func addGoal(_ app: XCUIApplication, subject: String, target: String,
                         unit: String, total: String, type: String? = nil) {
        app.buttons["添加目标"].tap()

        let subjectField = app.textFields["科目（如 高数）"]
        XCTAssertTrue(subjectField.waitForExistence(timeout: 5), "add-goal sheet must appear")
        subjectField.tap()
        subjectField.typeText(subject)

        if let type {
            // Picker in a Form exposes as one button labelled "类型, <current value>".
            button(app, startingWith: "类型").tap()
            app.buttons[type].tap()
        }

        let targetField = app.textFields["目标描述（如 完成6章）"]
        targetField.tap()
        targetField.typeText(target)

        replace(app.textFields["单位"], with: unit)
        replace(app.textFields["总量"], with: total)

        app.buttons["添加"].tap()
    }

    // MARK: - 1. Empty state → month setup → 保底学习日 preview

    func test01_EmptyStateAndMonthSetup() {
        let app = launch(today: studyDay)

        // Empty state guides to month setup, and its CTA must be reachable
        // (it was hidden behind the floating tab bar before this was fixed).
        let cta = app.buttons["去建月目标"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10), "empty-state CTA must exist")
        XCTAssertTrue(cta.isHittable, "empty-state CTA must not be covered by the tab bar")
        attach(app, "01-empty-state")

        cta.tap()
        XCTAssertTrue(app.staticTexts["保底学习日"].waitForExistence(timeout: 5),
                      "CTA routes to 月计划")

        addGoal(app, subject: "高数", target: "完成6章", unit: "章", total: "6")
        addGoal(app, subject: "线代", target: "100题", unit: "题", total: "100")
        addGoal(app, subject: "英语", target: "每天阅读", unit: "天", total: "31", type: "每天做")

        attach(app, "02-month-setup")

        // 学5休2 over August (31 days) → backbone 23, guaranteed 23 − 2 flex = 21.
        XCTAssertTrue(app.staticTexts["21"].exists, "保底学习日 preview must read 21")
        XCTAssertTrue(app.staticTexts["23"].exists, "骨架学习日 preview must read 23")

        app.buttons["确认并生成本月骨架"].tap()
    }

    // MARK: - 2. Study day: energy → plan + reasoning → evening report

    func test02_StudyDayLoop() {
        let app = launch(today: studyDay)
        app.buttons["去建月目标"].tap()
        addGoal(app, subject: "高数", target: "完成6章", unit: "章", total: "6")
        addGoal(app, subject: "线代", target: "100题", unit: "题", total: "100")
        addGoal(app, subject: "英语", target: "每天阅读", unit: "天", total: "31", type: "每天做")
        app.buttons["确认并生成本月骨架"].tap()

        app.buttons["今天"].tap()

        // Three energy choices must be offered on a study day.
        XCTAssertTrue(button(app, startingWith: "高能").waitForExistence(timeout: 5))
        XCTAssertTrue(button(app, startingWith: "普通").exists)
        XCTAssertTrue(button(app, startingWith: "低谷").exists)
        attach(app, "03-energy-picker")

        button(app, startingWith: "普通").tap()

        // Plan + reasoning render, and the reasoning must carry real numbers (§1.7).
        XCTAssertTrue(text(app, containing: "件事").waitForExistence(timeout: 5),
                      "plan summary must render")
        XCTAssertTrue(text(app, containing: "普通日，预算100分钟").exists,
                      "reasoning card must state the budget")
        attach(app, "04-plan-normal")

        // Evening report entry must be reachable, not buried under the tab bar.
        let reportCTA = app.buttons["去汇报今天"]
        XCTAssertTrue(reportCTA.exists)
        XCTAssertTrue(reportCTA.isHittable, "evening-report CTA must be tappable")
        reportCTA.tap()

        XCTAssertTrue(app.staticTexts["今天做得怎么样？"].waitForExistence(timeout: 5))
        let sliders = app.sliders
        XCTAssertGreaterThan(sliders.count, 0, "one slider per planned item")
        sliders.element(boundBy: 0).adjust(toNormalizedSliderPosition: 0.8)
        attach(app, "05-evening-report")

        app.buttons["完成汇报 · 今天结束"].tap()

        // Back on the plan screen, the streak counts today.
        XCTAssertTrue(text(app, containing: "1 天").waitForExistence(timeout: 5),
                      "streak badge must count today")
        attach(app, "06-after-report")
    }

    // MARK: - 3. Progress dashboard shows both goal types

    func test03_ProgressDashboard() {
        let app = launch(today: studyDay)
        app.buttons["去建月目标"].tap()
        addGoal(app, subject: "高数", target: "完成6章", unit: "章", total: "6")
        addGoal(app, subject: "英语", target: "每天阅读", unit: "天", total: "31", type: "每天做")
        app.buttons["确认并生成本月骨架"].tap()

        app.buttons["今天"].tap()
        button(app, startingWith: "普通").tap()
        app.buttons["去汇报今天"].tap()
        app.sliders.element(boundBy: 0).adjust(toNormalizedSliderPosition: 1.0)
        app.buttons["完成汇报 · 今天结束"].tap()

        app.buttons["进度"].tap()
        XCTAssertTrue(app.staticTexts["各科完成率"].waitForExistence(timeout: 5))
        // P4: habits are measured as completed study days, in their own section.
        XCTAssertTrue(app.staticTexts["习惯 · 完成学习日占比"].exists,
                      "habit section must exist (P4)")
        attach(app, "07-progress-dashboard")

        // Phase-P screens are reachable from the settings rows.
        XCTAssertTrue(app.buttons["提醒设置"].exists, "notification settings must be linked")
        app.buttons["提醒设置"].tap()
        XCTAssertTrue(app.staticTexts["生成今日计划"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["早晨提醒"].exists)
        attach(app, "08-notification-settings")
    }

    // MARK: - 4. Rest day: no tasks, no punishment, system still running

    func test04_RestDay() {
        let app = launch(today: restDay)
        app.buttons["去建月目标"].tap()
        addGoal(app, subject: "高数", target: "完成6章", unit: "章", total: "6")
        app.buttons["确认并生成本月骨架"].tap()
        app.buttons["今天"].tap()

        XCTAssertTrue(app.staticTexts["今天是计划内的休息日"].waitForExistence(timeout: 5),
                      "rest day shows the rest card, not an energy picker")
        XCTAssertFalse(button(app, startingWith: "高能").exists, "no energy picker on a rest day")
        XCTAssertTrue(text(app, containing: "系统仍在运行").exists,
                      "rest card must say the system is still running")
        attach(app, "09-rest-day")
    }

    // MARK: - 5. Flex rest: spend one, quota drops, undo restores

    func test05_FlexRest() {
        let app = launch(today: studyDay)
        app.buttons["去建月目标"].tap()
        addGoal(app, subject: "高数", target: "完成6章", unit: "章", total: "6")
        app.buttons["确认并生成本月骨架"].tap()
        app.buttons["今天"].tap()
        button(app, startingWith: "普通").tap()

        let flex = button(app, startingWith: "用一个灵活休息日")
        XCTAssertTrue(flex.waitForExistence(timeout: 5))
        XCTAssertTrue(flex.isHittable)
        flex.tap()

        XCTAssertTrue(app.staticTexts["今天先歇一下"].waitForExistence(timeout: 5))
        XCTAssertTrue(text(app, containing: "剩余1个").exists,
                      "flex card must show the remaining quota")
        attach(app, "10-flex-rest")

        button(app, startingWith: "点错了").tap()
        XCTAssertTrue(button(app, startingWith: "高能").waitForExistence(timeout: 5),
                      "undo returns to the study-day energy picker")
    }
}
