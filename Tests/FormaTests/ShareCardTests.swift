import XCTest
import SwiftUI
@testable import Forma

// Карточка «поделиться»: тексты проверяются без отрисовки, сама отрисовка — на реальных данных приложения.

private func makeAchievement(title: String = "Первые 5 000", xp: Int = 150) -> FormaAchievement {
    FormaAchievement(
        id: "first_5k",
        title: title,
        description: "Пройти 5 000 шагов за один день",
        icon: "figure.walk",
        category: .steps,
        xpReward: xp,
        targetValue: 5_000,
        currentValue: 5_000,
        isUnlocked: true
    )
}

private func makeSummary(trend: Int? = 12, habits: Int? = 78) -> WeeklySummary {
    var summary = WeeklySummary()
    summary.totalSteps = 63_400
    summary.averageSteps = 9_057
    summary.workoutCount = 4
    summary.workoutMinutes = 160
    summary.stepsChangePercent = trend
    summary.habitsPercent = habits
    return summary
}

// MARK: - Тексты карточек

final class ShareCardModelTests: XCTestCase {

    func testAchievementCardShowsTitleRewardAndDescription() {
        let model = ShareCardModel.achievement(makeAchievement(), lang: "ru")

        XCTAssertEqual(model.headline, "Первые 5 000")
        XCTAssertEqual(model.metric, "+150")
        XCTAssertEqual(model.metricCaption, "XP")
        XCTAssertEqual(model.details, ["Пройти 5 000 шагов за один день"])
        XCTAssertEqual(model.symbol, "figure.walk")
        XCTAssertEqual(model.eyebrow, "Новая награда")
    }

    func testWeeklyCardShowsStepsWorkoutsHabitsAndTrend() {
        let model = ShareCardModel.weekly(makeSummary(), period: "20 окт – 26 окт", lang: "ru")

        XCTAssertEqual(model.headline, "20 окт – 26 окт")
        XCTAssertEqual(model.metric, "63\u{00A0}400")
        XCTAssertEqual(model.metricCaption, "шагов за 7 дней")
        XCTAssertEqual(model.details.count, 3)
        XCTAssertTrue(model.details[0].contains("4 · 160"), "Тренировки: число и минуты — \(model.details[0])")
        XCTAssertTrue(model.details[1].contains("78%"), "Привычки — \(model.details[1])")
        XCTAssertTrue(model.details[2].contains("12%"), "Рост к прошлой неделе — \(model.details[2])")
    }

    func testWeeklyCardSkipsMissingHabitsAndTrend() {
        let model = ShareCardModel.weekly(makeSummary(trend: nil, habits: nil), period: "", lang: "ru")
        XCTAssertEqual(model.details.count, 1, "Остаются только тренировки")
    }

    func testWeeklyCardShowsDeclineAsFewerSteps() {
        let model = ShareCardModel.weekly(makeSummary(trend: -30, habits: nil), period: "", lang: "ru")
        XCTAssertTrue(model.details.contains { $0.contains("30%") && $0.contains("меньше") })
    }

    func testWeeklyCardNeverHasMoreLinesThanFitOnTheCard() {
        let model = ShareCardModel.weekly(makeSummary(), period: "", lang: "ru")
        XCTAssertLessThanOrEqual(model.details.count, ShareCardModel.maxDetails)
    }

    func testWorkoutCardShowsMinutesCaloriesDistanceAndExperience() {
        let model = ShareCardModel.workout(title: "Бег на улице", symbol: "figure.run", durationSeconds: 1_845,
                                           calories: 312.4, distanceMeters: 5_230, xp: 150, lang: "ru")

        XCTAssertEqual(model.headline, "Бег на улице")
        XCTAssertEqual(model.metric, "31", "1 845 секунд — это 31 минута")
        XCTAssertEqual(model.metricCaption, "мин")
        XCTAssertEqual(model.details, ["312 ккал", "5.23 км", "+150 XP"])
    }

    func testWorkoutCardOmitsDistanceAndExperienceWhenThereIsNone() {
        let model = ShareCardModel.workout(title: "Йога", symbol: "figure.yoga", durationSeconds: 600,
                                           calories: 40, distanceMeters: 0, xp: 0, lang: "ru")
        XCTAssertEqual(model.details, ["40 ккал"])
    }

    func testVeryShortWorkoutShowsAtLeastOneMinute() {
        let model = ShareCardModel.workout(title: "Растяжка", symbol: "figure.flexibility", durationSeconds: 20,
                                           calories: 3, distanceMeters: 0, xp: 0, lang: "ru")
        XCTAssertEqual(model.metric, "1")
    }

    func testStreakCardShowsDaysInARow() {
        let model = ShareCardModel.streak(days: 21, lang: "ru")
        XCTAssertEqual(model.metric, "21")
        XCTAssertEqual(model.metricCaption, "дней подряд")
        XCTAssertEqual(model.symbol, "flame.fill")
    }

    func testCardsFollowTheRequestedLanguage() {
        XCTAssertEqual(ShareCardModel.achievement(makeAchievement(), lang: "en").eyebrow, "New achievement")
        XCTAssertEqual(ShareCardModel.streak(days: 3, lang: "en").metricCaption, "days in a row")
        XCTAssertEqual(ShareCardModel.weekly(makeSummary(), period: "", lang: "en").metricCaption, "steps in 7 days")
    }

    func testEveryNewTextIsTranslatedIntoAllLanguages() {
        let keys = ["share_button", "share_footer", "share_eyebrow_achievement", "share_eyebrow_streak",
                    "share_streak_headline", "share_streak_caption", "weekly_summary_title", "weekly_summary_notification_body",
                    "weekly_summary_empty", "weekly_summary_trend_up", "weekly_summary_trend_down", "cloud_sync_title", "cloud_sync_desc"]
        for key in keys {
            for lang in ["ru", "en", "hy"] {
                let text = LocalizationManager.tr(key, lang: lang)
                XCTAssertFalse(text.isEmpty, "\(key) / \(lang): пусто")
                XCTAssertNotEqual(text, key, "\(key) / \(lang): перевода нет, показался бы сам ключ")
            }
        }
    }
}

// MARK: - Отрисовка

@MainActor
final class ShareCardRendererTests: XCTestCase {

    private func pixelSize(of image: UIImage) -> CGSize {
        CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    }

    func testAchievementCardRendersAtStoryFormat() throws {
        let image = try XCTUnwrap(ShareCardRenderer.image(for: .achievement(makeAchievement()), lang: "ru"))
        XCTAssertEqual(pixelSize(of: image), ShareCardView.size, "Размер не должен зависеть от экрана устройства")
    }

    func testWeeklyCardRendersAtStoryFormat() throws {
        let model = ShareCardModel.weekly(makeSummary(), period: "20 окт – 26 окт", lang: "ru")
        let image = try XCTUnwrap(ShareCardRenderer.image(for: model, lang: "ru"))
        XCTAssertEqual(pixelSize(of: image), ShareCardView.size)
    }

    func testStreakCardRendersAtStoryFormat() throws {
        let image = try XCTUnwrap(ShareCardRenderer.image(for: .streak(days: 365), lang: "ru"))
        XCTAssertEqual(pixelSize(of: image), ShareCardView.size)
    }

    func testVeryLongTitleStillRenders() throws {
        let long = String(repeating: "Невероятно длинное название награды ", count: 6)
        let image = try XCTUnwrap(ShareCardRenderer.image(for: .achievement(makeAchievement(title: long)), lang: "ru"))
        XCTAssertEqual(pixelSize(of: image), ShareCardView.size, "Длинный текст сжимается, а не растягивает карточку")
    }

    func testRenderedCardIsNotBlank() throws {
        let image = try XCTUnwrap(ShareCardRenderer.image(for: .streak(days: 7), lang: "ru"))
        let cgImage = try XCTUnwrap(image.cgImage)
        let data = try XCTUnwrap(cgImage.dataProvider?.data)
        let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
        let length = CFDataGetLength(data)
        // Картинка не должна быть одноцветной: на ней фон, медальон и текст
        var distinct = Set<UInt8>()
        var index = 0
        while index < length && distinct.count < 16 {
            distinct.insert(bytes[index])
            index += 997
        }
        XCTAssertGreaterThan(distinct.count, 8)
    }
}
