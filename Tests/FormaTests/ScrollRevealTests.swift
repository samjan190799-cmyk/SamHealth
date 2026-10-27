import XCTest
@testable import Forma

/// Эффект «карусели» при прокрутке: карточка тускнеет и сжимается у края экрана.
/// Видимая область в этих тестах — 0...800 pt.
final class ScrollRevealTests: XCTestCase {

    private func visibility(minY: CGFloat, maxY: CGFloat) -> CGFloat {
        FormaScrollReveal.visibility(minY: minY, maxY: maxY, viewportMinY: 0, viewportMaxY: 800)
    }

    func testCardInsideViewportIsUntouched() {
        XCTAssertEqual(visibility(minY: 300, maxY: 500), 1, accuracy: 1e-9)
        XCTAssertEqual(FormaScrollReveal.opacity(visibility: 1), 1, accuracy: 1e-9)
        XCTAssertEqual(FormaScrollReveal.scale(visibility: 1), 1, accuracy: 1e-9)
    }

    func testCardFullyAboveOrBelowIsFullyFaded() {
        XCTAssertEqual(visibility(minY: -400, maxY: -100), 0, accuracy: 1e-9, "Целиком выше экрана")
        XCTAssertEqual(visibility(minY: 900, maxY: 1100), 0, accuracy: 1e-9, "Целиком ниже экрана")
        XCTAssertEqual(FormaScrollReveal.opacity(visibility: 0), 0.5, accuracy: 1e-9)
        XCTAssertEqual(FormaScrollReveal.scale(visibility: 0), 0.97, accuracy: 1e-9)
    }

    func testCardLeavingAtTopFadesGradually() {
        // Карточка высотой 200: её нижний край уходит за верх экрана
        var previous: CGFloat = 1
        for bottom in stride(from: CGFloat(200), through: 0, by: -20) {
            let value = visibility(minY: bottom - 200, maxY: bottom)
            XCTAssertLessThanOrEqual(value, previous + 1e-9, "Чем дальше за край, тем слабее видимость")
            previous = value
        }
        XCTAssertEqual(previous, 0, accuracy: 1e-9)
    }

    func testCardEnteringFromBottomFadesGradually() {
        let enteringHalf = visibility(minY: 700, maxY: 900)   // верхний край в 100 pt от низа
        XCTAssertGreaterThan(enteringHalf, 0)
        XCTAssertLessThan(enteringHalf, 1)
    }

    func testTallBlockCrossingBothEdgesIsNotDimmed() {
        // Блок выше экрана (например, длинная карточка профиля): его читают, он не должен тускнеть
        XCTAssertEqual(visibility(minY: -300, maxY: 1500), 1, accuracy: 1e-9)
        XCTAssertEqual(visibility(minY: -50, maxY: 1200), 1, accuracy: 1e-9)
    }

    func testFadeZoneIsCappedForTallBlocks() {
        // У очень высокого блока затухание начинается только в последних 220 pt у края
        let farFromEdge = visibility(minY: -2000, maxY: 300)   // нижний край в 300 pt от верха
        XCTAssertEqual(farFromEdge, 1, accuracy: 1e-9)
        let nearEdge = visibility(minY: -2000, maxY: 110)      // 110 из 220 pt
        XCTAssertEqual(nearEdge, 0.5, accuracy: 1e-9)
    }

    func testCardsInTheMiddleOfAnyScreenAreUntouched() {
        // Регрессия: из-за неверных координат карточки ниже середины экрана тускнели до минимума.
        // Для экранов разной высоты карточка в 100 pt, лежащая на 40-80 % высоты, не должна затухать.
        for height in [667, 812, 874, 932] as [CGFloat] {
            for fraction in [0.4, 0.55, 0.7, 0.8] as [CGFloat] {
                let top = height * fraction
                let value = FormaScrollReveal.visibility(minY: top, maxY: top + 100, viewportMinY: 0, viewportMaxY: height)
                XCTAssertEqual(value, 1, accuracy: 1e-9, "Экран \(height) pt, карточка на \(fraction * 100) %")
            }
        }
    }

    func testNoScrollViewMeansNoEffect() {
        let value = FormaScrollReveal.visibility(minY: 100, maxY: 300, viewportMinY: 0, viewportMaxY: 0)
        XCTAssertEqual(value, 1)
    }

    func testOpacityAndScaleStayInBounds() {
        for step in stride(from: CGFloat(-1), through: 2, by: 0.25) {
            let opacity = FormaScrollReveal.opacity(visibility: step)
            let scale = FormaScrollReveal.scale(visibility: step)
            XCTAssertTrue((0.5...1).contains(opacity))
            XCTAssertTrue((0.97...1).contains(scale))
        }
    }
}
