import XCTest
@testable import PlateDepthKit

final class PlateDepthAnalyzerTests: XCTestCase {

    /// Рамка съёмки в центре кадра: ~60% × 70% (в кадре 49 см по ширине на расстоянии 40 см).
    private let region = PlateDepthRegion(x0: 0.20, y0: 0.15, x1: 0.80, y1: 0.85)

    private func measure(_ scene: SyntheticScene, noise: Double = 0, dropout: Double = 0) throws -> PlateMeasurement {
        let depth = scene.render(noiseSigma: noise, dropoutFraction: dropout)
        return try PlateDepthAnalyzer.measure(grid: scene.grid(meters: depth), region: region).get()
    }

    private func assertRelative(_ actual: Double, _ expected: Double, tolerance: Double,
                                _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let error = abs(actual - expected) / expected
        print(String(format: "  %@: %.2f (ожидалось %.2f, ошибка %.1f%%)", label, actual, expected, error * 100))
        XCTAssertLessThanOrEqual(error, tolerance,
            "\(label): получено \(actual), ожидалось \(expected) (ошибка \(Int(error * 100))%)", file: file, line: line)
    }

    // Цилиндр R = 8 см, H = 3 см: объём 603 см³, площадь 201 см², диаметр 16 см
    private let plate = SyntheticScene.Cylinder(centerU: 0, centerV: 0, radius: 0.08, height: 0.03)
    private var plateVolumeCm3: Double { Double.pi * 0.08 * 0.08 * 0.03 * 1_000_000 }
    private var plateFootprintCm2: Double { Double.pi * 0.08 * 0.08 * 10_000 }

    func testFlatTableTopDown() throws {
        var scene = SyntheticScene()
        scene.cylinders = [plate]
        let m = try measure(scene)

        assertRelative(m.volumeAboveTableCm3, plateVolumeCm3, tolerance: 0.05, "объём")
        assertRelative(m.footprintCm2, plateFootprintCm2, tolerance: 0.05, "площадь")
        assertRelative(m.equivalentDiameterCm, 16, tolerance: 0.04, "диаметр")
        assertRelative(m.maxHeightCm, 3, tolerance: 0.06, "высота")
        assertRelative(m.tableDistanceMeters, 0.40, tolerance: 0.01, "расстояние до стола")
        XCTAssertFalse(m.objectTouchesFrameEdge)
        XCTAssertGreaterThan(m.confidence, 0.8)
    }

    func testTiltedTableStillMeasuresTrueSize() throws {
        // Камера наклонена ~17° и ~9° относительно стола: без учёта наклона объём «уплывает»
        var scene = SyntheticScene()
        scene.a = 0.30
        scene.b = -0.15
        scene.c = 0.42
        scene.cylinders = [plate]
        let m = try measure(scene)

        assertRelative(m.volumeAboveTableCm3, plateVolumeCm3, tolerance: 0.07, "объём (наклон)")
        assertRelative(m.footprintCm2, plateFootprintCm2, tolerance: 0.07, "площадь (наклон)")
        assertRelative(m.maxHeightCm, 3, tolerance: 0.08, "высота (наклон)")
    }

    func testMeasurementDoesNotDependOnCameraDistance() throws {
        // Старая подделка росла с расстоянием; настоящий замер — нет.
        var near = SyntheticScene(); near.c = 0.32; near.cylinders = [plate]
        var far = SyntheticScene(); far.c = 0.55; far.cylinders = [plate]
        let mNear = try measure(near)
        let mFar = try measure(far)

        assertRelative(mNear.volumeAboveTableCm3, plateVolumeCm3, tolerance: 0.06, "объём вблизи")
        assertRelative(mFar.volumeAboveTableCm3, plateVolumeCm3, tolerance: 0.08, "объём вдали")
    }

    func testNoiseAndDropouts() throws {
        var scene = SyntheticScene()
        scene.cylinders = [plate]
        let m = try measure(scene, noise: 0.003, dropout: 0.05)

        assertRelative(m.volumeAboveTableCm3, plateVolumeCm3, tolerance: 0.12, "объём при шуме 3 мм и 5% пропусков")
        assertRelative(m.equivalentDiameterCm, 16, tolerance: 0.08, "диаметр при шуме")
    }

    func testOffCenterObject() throws {
        var scene = SyntheticScene()
        scene.cylinders = [.init(centerU: 0.05, centerV: -0.03, radius: 0.07, height: 0.04)]
        let m = try measure(scene)
        assertRelative(m.volumeAboveTableCm3, Double.pi * 0.07 * 0.07 * 0.04 * 1_000_000, tolerance: 0.07, "объём (смещён)")
    }

    func testObjectLargerThanRegionIsFlagged() throws {
        // Диаметр 32 см при рамке ~29×26 см: стол в углах кадра виден, но часть блюда вне рамки
        var scene = SyntheticScene()
        scene.cylinders = [.init(centerU: 0, centerV: 0, radius: 0.16, height: 0.08)]
        let m = try measure(scene)
        XCTAssertTrue(m.objectTouchesFrameEdge, "объект больше рамки должен быть помечен")
    }

    func testObjectFillingWholeFrameFailsSafely() {
        // Стола в кадре нет вообще: отмерять высоту не от чего. Должен быть отказ, а не выдуманное число.
        var scene = SyntheticScene()
        scene.cylinders = [.init(centerU: 0, centerV: 0, radius: 0.5, height: 0.08)]
        let result = PlateDepthAnalyzer.measure(grid: scene.grid(meters: scene.render()), region: region)
        if case .success(let m) = result {
            XCTFail("Ожидался отказ, получен замер: \(m)")
        }
    }

    func testEmptyTable() {
        let scene = SyntheticScene()
        let result = PlateDepthAnalyzer.measure(grid: scene.grid(meters: scene.render()), region: region)
        XCTAssertEqual(result, .failure(.nothingOnTable))
    }

    func testThinFilmBelowNoiseFloorIsIgnored() {
        var scene = SyntheticScene()
        scene.cylinders = [.init(centerU: 0, centerV: 0, radius: 0.08, height: 0.006)]
        let result = PlateDepthAnalyzer.measure(grid: scene.grid(meters: scene.render()), region: region)
        XCTAssertEqual(result, .failure(.nothingOnTable))
    }

    func testRelativeDepthIsRejected() {
        var scene = SyntheticScene()
        scene.cylinders = [plate]
        let grid = scene.grid(meters: scene.render(), absolute: false)
        XCTAssertEqual(PlateDepthAnalyzer.measure(grid: grid, region: region), .failure(.relativeDepthOnly))
    }

    func testNoDataIsRejected() {
        let scene = SyntheticScene()
        let empty = [Float](repeating: .nan, count: scene.width * scene.height)
        let result = PlateDepthAnalyzer.measure(grid: scene.grid(meters: empty), region: region)
        XCTAssertEqual(result, .failure(.tablePlaneNotFound))
    }

    func testMostlyInvalidRegionIsRejected() {
        var scene = SyntheticScene()
        scene.cylinders = [plate]
        var depth = scene.render()
        // Стираем глубину внутри рамки (блики / чёрная посуда), стол снаружи остаётся
        for py in 43..<245 { for px in 77..<308 { depth[py * scene.width + px] = .nan } }
        let result = PlateDepthAnalyzer.measure(grid: scene.grid(meters: depth), region: region)
        XCTAssertEqual(result, .failure(.tooFewValidPixels))
    }

    func testInvalidIntrinsicsAreRejected() {
        let scene = SyntheticScene()
        let grid = PlateDepthGrid(width: scene.width, height: scene.height, meters: scene.render(),
                                  fx: 0, fy: 0, cx: 0, cy: 0, hasAbsoluteScale: true, isHighQuality: true)
        XCTAssertEqual(PlateDepthAnalyzer.measure(grid: grid, region: region), .failure(.invalidGeometry))
    }

    func testResultIsDeterministic() throws {
        var scene = SyntheticScene()
        scene.a = 0.2
        scene.cylinders = [plate]
        let depth = scene.render(noiseSigma: 0.003)
        let first = try PlateDepthAnalyzer.measure(grid: scene.grid(meters: depth), region: region).get()
        let second = try PlateDepthAnalyzer.measure(grid: scene.grid(meters: depth), region: region).get()
        XCTAssertEqual(first, second)
    }
}
