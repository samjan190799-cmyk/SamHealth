import Foundation

// MARK: - Геометрия блюда по карте глубины (LiDAR)
//
// Файл намеренно не зависит от AVFoundation/UIKit: на вход приходит обычный массив
// метров, на выходе — физические размеры объекта на столе. Благодаря этому алгоритм
// проверяется юнит-тестами на синтетических сценах (Tests/PlateDepth).
//
// Модель сцены: камера смотрит на стол (плоскость), на столе стоит посуда с едой.
//   1. Плоскость стола ищется по пикселям ВНЕ рамки съёмки (RANSAC + МНК по инлайерам).
//   2. Для каждого пикселя рамки считается высота над плоскостью и площадь, которую он
//      покрывает на плоскости (с поправкой на наклон камеры).
//   3. Объём = Σ высота × площадь по пикселям, поднятым над столом.
//
// Замер — это ГЕОМЕТРИЯ, а не вес: объём включает саму посуду (дно тарелки 1–2 см),
// а плотность зависит от блюда. Вес выводит модель, используя эти числа как масштаб.

/// Прямоугольник в нормализованных координатах кадра сенсора (0...1, начало — левый верхний угол).
public struct PlateDepthRegion: Equatable {
    public var x0: Double
    public var y0: Double
    public var x1: Double
    public var y1: Double

    public init(x0: Double, y0: Double, x1: Double, y1: Double) {
        self.x0 = x0
        self.y0 = y0
        self.x1 = x1
        self.y1 = y1
    }
}

/// Карта глубины в метрах вместе с внутренними параметрами камеры (в пикселях ЭТОЙ карты).
public struct PlateDepthGrid {
    public let width: Int
    public let height: Int
    /// Глубина вдоль оптической оси, метры. NaN / ≤ 0 — данных нет. Построчно, сверху вниз.
    public let meters: [Float]
    public let fx: Double
    public let fy: Double
    public let cx: Double
    public let cy: Double
    /// `true`, если значения — реальные метры (LiDAR). Относительная глубина не годится для объёма.
    public let hasAbsoluteScale: Bool
    public let isHighQuality: Bool

    public init(
        width: Int,
        height: Int,
        meters: [Float],
        fx: Double,
        fy: Double,
        cx: Double,
        cy: Double,
        hasAbsoluteScale: Bool,
        isHighQuality: Bool
    ) {
        self.width = width
        self.height = height
        self.meters = meters
        self.fx = fx
        self.fy = fy
        self.cx = cx
        self.cy = cy
        self.hasAbsoluteScale = hasAbsoluteScale
        self.isHighQuality = isHighQuality
    }
}

/// Физические размеры объекта на столе внутри рамки съёмки.
public struct PlateMeasurement: Equatable {
    /// Расстояние от камеры до стола вдоль оптической оси, м.
    public let tableDistanceMeters: Double
    /// Площадь, которую объект занимает на столе, см².
    public let footprintCm2: Double
    /// Диаметр круга той же площади, см (масштаб посуды).
    public let equivalentDiameterCm: Double
    /// Высота над столом: 95-й перцентиль, см (устойчива к одиночным выбросам).
    public let maxHeightCm: Double
    public let meanHeightCm: Double
    /// Объём между столом и верхней поверхностью, см³. Включает посуду.
    public let volumeAboveTableCm3: Double
    /// Объект упирается в границу рамки: часть его вне кадра, объём занижен.
    public let objectTouchesFrameEdge: Bool
    /// 0...1: насколько можно доверять замеру.
    public let confidence: Double

    public init(
        tableDistanceMeters: Double,
        footprintCm2: Double,
        equivalentDiameterCm: Double,
        maxHeightCm: Double,
        meanHeightCm: Double,
        volumeAboveTableCm3: Double,
        objectTouchesFrameEdge: Bool,
        confidence: Double
    ) {
        self.tableDistanceMeters = tableDistanceMeters
        self.footprintCm2 = footprintCm2
        self.equivalentDiameterCm = equivalentDiameterCm
        self.maxHeightCm = maxHeightCm
        self.meanHeightCm = meanHeightCm
        self.volumeAboveTableCm3 = volumeAboveTableCm3
        self.objectTouchesFrameEdge = objectTouchesFrameEdge
        self.confidence = confidence
    }
}

public enum PlateDepthAnalyzer {

    public enum Failure: Error, Equatable {
        /// Глубина относительная (двойная камера), метров в ней нет.
        case relativeDepthOnly
        /// Пустая/несогласованная карта, нулевые фокусные расстояния, слишком маленькая рамка.
        case invalidGeometry
        /// В рамке слишком мало пикселей с глубиной (блики, чёрная посуда, вне диапазона).
        case tooFewValidPixels
        /// Вне рамки не нашлось плоской поверхности — не от чего отмерять высоту.
        case tablePlaneNotFound
        /// Над столом в рамке ничего нет.
        case nothingOnTable
    }

    public struct Configuration {
        public var minDepthMeters: Double = 0.15
        public var maxDepthMeters: Double = 1.5
        /// Допуск, в пределах которого пиксель считается лежащим на плоскости стола.
        public var planeInlierToleranceMeters: Double = 0.008
        /// Ниже этой высоты пиксель — шум стола, а не еда.
        public var minObjectHeightMeters: Double = 0.012
        /// Выше — рука, чашка в воздухе и прочие посторонние объекты.
        public var maxObjectHeightMeters: Double = 0.35
        public var minPlaneInlierFraction: Double = 0.30
        public var minValidRegionFraction: Double = 0.30
        public var ransacIterations: Int = 150
        public var maxTablePlaneSamples: Int = 3000
        public var minFootprintCm2: Double = 12.0
        /// Предельный наклон плоскости стола (|dz/dx|, |dz/dy|): 1.5 ≈ 56°.
        public var maxPlaneSlope: Double = 1.5

        public init() {}
        public static let standard = Configuration()
    }

    // MARK: Публичный API

    public static func measure(
        grid: PlateDepthGrid,
        region: PlateDepthRegion,
        configuration: Configuration = .standard
    ) -> Result<PlateMeasurement, Failure> {
        guard grid.hasAbsoluteScale else { return .failure(.relativeDepthOnly) }

        let w = grid.width
        let h = grid.height
        guard w >= 16, h >= 16,
              grid.meters.count == w * h,
              grid.fx.isFinite, grid.fy.isFinite, grid.cx.isFinite, grid.cy.isFinite,
              grid.fx > 0, grid.fy > 0,
              region.x0.isFinite, region.y0.isFinite, region.x1.isFinite, region.y1.isFinite else {
            return .failure(.invalidGeometry)
        }

        let rx0 = clamp(Int((min(region.x0, region.x1) * Double(w)).rounded(.down)), 0, w - 1)
        let ry0 = clamp(Int((min(region.y0, region.y1) * Double(h)).rounded(.down)), 0, h - 1)
        let rx1 = clamp(Int((max(region.x0, region.x1) * Double(w)).rounded(.up)), rx0, w)
        let ry1 = clamp(Int((max(region.y0, region.y1) * Double(h)).rounded(.up)), ry0, h)
        guard rx1 - rx0 >= 8, ry1 - ry0 >= 8 else { return .failure(.invalidGeometry) }
        let regionArea = (rx1 - rx0) * (ry1 - ry0)

        // 1. Плоскость стола
        var samples = tableSamples(
            grid: grid, rx0: rx0, ry0: ry0, rx1: rx1, ry1: ry1, configuration: configuration, useRegionRing: false
        )
        var tableFromRing = false
        if samples.count < 200 {
            // Рамка занимает почти весь кадр — берём краевое кольцо самой рамки (менее надёжно).
            samples = tableSamples(
                grid: grid, rx0: rx0, ry0: ry0, rx1: rx1, ry1: ry1, configuration: configuration, useRegionRing: true
            )
            tableFromRing = true
        }
        guard samples.count >= 100,
              let plane = fitTablePlane(samples: samples, configuration: configuration) else {
            return .failure(.tablePlaneNotFound)
        }

        // 2. Объект над столом
        let norm = (1.0 + plane.a * plane.a + plane.b * plane.b).squareRoot()
        let minH = configuration.minObjectHeightMeters
        let maxH = configuration.maxObjectHeightMeters

        var validPixels = 0
        var objectPixels = 0
        var edgePixels = 0
        var footprintM2 = 0.0
        var volumeM3 = 0.0
        var heightSum = 0.0
        var heights: [Float] = []

        for py in ry0..<ry1 {
            for px in rx0..<rx1 {
                let z = Double(grid.meters[py * w + px])
                guard z.isFinite, z >= configuration.minDepthMeters, z <= configuration.maxDepthMeters else { continue }
                validPixels += 1

                let x = (Double(px) + 0.5 - grid.cx) / grid.fx * z
                let y = (Double(py) + 0.5 - grid.cy) / grid.fy * z
                let height = (plane.a * x + plane.b * y + plane.c - z) / norm
                guard height >= minH, height <= maxH else { continue }

                // Площадь на плоскости, которую закрывает один пиксель: боковое покрытие
                // (z/fx)(z/fy) делённое на косинус угла между нормалью стола и оптической осью.
                let pixelArea = z * z / (grid.fx * grid.fy) * norm
                footprintM2 += pixelArea
                volumeM3 += height * pixelArea
                heightSum += height
                heights.append(Float(height))
                objectPixels += 1

                if px < rx0 + 2 || px >= rx1 - 2 || py < ry0 + 2 || py >= ry1 - 2 {
                    edgePixels += 1
                }
            }
        }

        guard Double(validPixels) >= configuration.minValidRegionFraction * Double(regionArea) else {
            return .failure(.tooFewValidPixels)
        }
        let footprintCm2 = footprintM2 * 10_000.0
        guard objectPixels >= 20, footprintCm2 >= configuration.minFootprintCm2 else {
            return .failure(.nothingOnTable)
        }

        heights.sort()
        let p95 = Double(heights[Int(Double(heights.count - 1) * 0.95)])

        // 3. Достоверность: качество плоскости, покрытие рамки, качество сенсора
        let planeScore = clamp01((plane.inlierFraction - configuration.minPlaneInlierFraction) / 0.45)
        let coverageScore = clamp01((Double(validPixels) / Double(regionArea) - 0.35) / 0.5)
        let qualityScore = grid.isHighQuality ? 1.0 : 0.6
        var confidence = 0.40 * planeScore + 0.35 * coverageScore + 0.25 * qualityScore
        if tableFromRing { confidence *= 0.7 }

        return .success(PlateMeasurement(
            tableDistanceMeters: plane.c,
            footprintCm2: footprintCm2,
            equivalentDiameterCm: 2.0 * (footprintCm2 / Double.pi).squareRoot(),
            maxHeightCm: p95 * 100.0,
            meanHeightCm: heightSum / Double(objectPixels) * 100.0,
            volumeAboveTableCm3: volumeM3 * 1_000_000.0,
            objectTouchesFrameEdge: edgePixels >= 4,
            confidence: clamp01(confidence)
        ))
    }

    // MARK: Плоскость стола

    struct Sample {
        var x: Double
        var y: Double
        var z: Double
    }

    /// Плоскость z = a·x + b·y + c в системе камеры (z — вперёд по оптической оси).
    struct Plane {
        var a: Double
        var b: Double
        var c: Double
        var inlierFraction: Double
    }

    static func tableSamples(
        grid: PlateDepthGrid,
        rx0: Int, ry0: Int, rx1: Int, ry1: Int,
        configuration: Configuration,
        useRegionRing: Bool
    ) -> [Sample] {
        let w = grid.width
        let h = grid.height
        let scanArea = useRegionRing ? (rx1 - rx0) * (ry1 - ry0) : w * h
        let step = max(1, Int((Double(scanArea) / Double(max(1, configuration.maxTablePlaneSamples))).squareRoot()))
        let ringWidth = max(2, Int(Double(min(rx1 - rx0, ry1 - ry0)) * 0.12))

        var result: [Sample] = []
        let yRange = useRegionRing ? (ry0..<ry1) : (0..<h)
        let xRange = useRegionRing ? (rx0..<rx1) : (0..<w)

        for py in stride(from: yRange.lowerBound, to: yRange.upperBound, by: step) {
            for px in stride(from: xRange.lowerBound, to: xRange.upperBound, by: step) {
                let insideRegion = px >= rx0 && px < rx1 && py >= ry0 && py < ry1
                if useRegionRing {
                    let onRing = px < rx0 + ringWidth || px >= rx1 - ringWidth || py < ry0 + ringWidth || py >= ry1 - ringWidth
                    if !onRing { continue }
                } else if insideRegion {
                    continue
                }
                let z = Double(grid.meters[py * w + px])
                guard z.isFinite, z >= configuration.minDepthMeters, z <= configuration.maxDepthMeters else { continue }
                result.append(Sample(
                    x: (Double(px) + 0.5 - grid.cx) / grid.fx * z,
                    y: (Double(py) + 0.5 - grid.cy) / grid.fy * z,
                    z: z
                ))
            }
        }
        return result
    }

    static func fitTablePlane(samples: [Sample], configuration: Configuration) -> Plane? {
        guard samples.count >= 3 else { return nil }
        let tolerance = configuration.planeInlierToleranceMeters
        var rng = SplitMix64(seed: 0x5EED_F00D_CAFE_2026)

        var bestPlane: (a: Double, b: Double, c: Double)?
        var bestInliers = 0

        for _ in 0..<configuration.ransacIterations {
            let i = Int(rng.next() % UInt64(samples.count))
            let j = Int(rng.next() % UInt64(samples.count))
            let k = Int(rng.next() % UInt64(samples.count))
            guard i != j, j != k, i != k,
                  let candidate = planeThrough(samples[i], samples[j], samples[k]),
                  abs(candidate.a) <= configuration.maxPlaneSlope,
                  abs(candidate.b) <= configuration.maxPlaneSlope else { continue }

            let count = inlierCount(samples: samples, plane: candidate, tolerance: tolerance)
            if count > bestInliers {
                bestInliers = count
                bestPlane = candidate
            }
        }
        guard var plane = bestPlane else { return nil }

        // Два прохода уточнения по МНК на инлайерах
        for _ in 0..<2 {
            let inliers = samples.filter { abs(height(of: $0, plane: plane)) <= tolerance }
            guard inliers.count >= 3, let refined = fitLeastSquares(inliers),
                  abs(refined.a) <= configuration.maxPlaneSlope,
                  abs(refined.b) <= configuration.maxPlaneSlope else { break }
            plane = refined
        }

        let finalInliers = inlierCount(samples: samples, plane: plane, tolerance: tolerance)
        let fraction = Double(finalInliers) / Double(samples.count)
        guard fraction >= configuration.minPlaneInlierFraction, plane.c > 0 else { return nil }
        return Plane(a: plane.a, b: plane.b, c: plane.c, inlierFraction: fraction)
    }

    /// Высота точки над плоскостью (в метрах, положительная — ближе к камере, то есть «над столом»).
    static func height(of s: Sample, plane p: (a: Double, b: Double, c: Double)) -> Double {
        (p.a * s.x + p.b * s.y + p.c - s.z) / (1.0 + p.a * p.a + p.b * p.b).squareRoot()
    }

    static func inlierCount(samples: [Sample], plane p: (a: Double, b: Double, c: Double), tolerance: Double) -> Int {
        let norm = (1.0 + p.a * p.a + p.b * p.b).squareRoot()
        var count = 0
        for s in samples where abs((p.a * s.x + p.b * s.y + p.c - s.z) / norm) <= tolerance {
            count += 1
        }
        return count
    }

    /// Плоскость точно через три точки (правило Крамера). `nil` — точки почти на одной прямой.
    static func planeThrough(_ p1: Sample, _ p2: Sample, _ p3: Sample) -> (a: Double, b: Double, c: Double)? {
        // Решаем [x y 1]·[a b c]ᵀ = z
        let det = p1.x * (p2.y - p3.y) - p1.y * (p2.x - p3.x) + (p2.x * p3.y - p3.x * p2.y)
        guard abs(det) > 2e-4 else { return nil } // удвоенная площадь треугольника в проекции ≥ 2 см²
        let detA = p1.z * (p2.y - p3.y) - p1.y * (p2.z - p3.z) + (p2.z * p3.y - p3.z * p2.y)
        let detB = p1.x * (p2.z - p3.z) - p1.z * (p2.x - p3.x) + (p2.x * p3.z - p3.x * p2.z)
        let detC = p1.x * (p2.y * p3.z - p3.y * p2.z) - p1.y * (p2.x * p3.z - p3.x * p2.z) + p1.z * (p2.x * p3.y - p3.x * p2.y)
        return (detA / det, detB / det, detC / det)
    }

    /// МНК: минимизирует Σ (z − a·x − b·y − c)².
    static func fitLeastSquares(_ points: [Sample]) -> (a: Double, b: Double, c: Double)? {
        var sxx = 0.0, sxy = 0.0, sx = 0.0, syy = 0.0, sy = 0.0
        var sxz = 0.0, syz = 0.0, sz = 0.0
        for p in points {
            sxx += p.x * p.x; sxy += p.x * p.y; sx += p.x
            syy += p.y * p.y; sy += p.y
            sxz += p.x * p.z; syz += p.y * p.z; sz += p.z
        }
        let n = Double(points.count)
        var m: [[Double]] = [
            [sxx, sxy, sx, sxz],
            [sxy, syy, sy, syz],
            [sx, sy, n, sz]
        ]
        // Гаусс с выбором главного элемента
        for col in 0..<3 {
            var pivot = col
            for row in (col + 1)..<3 where abs(m[row][col]) > abs(m[pivot][col]) {
                pivot = row
            }
            guard abs(m[pivot][col]) > 1e-12 else { return nil }
            m.swapAt(col, pivot)
            for row in 0..<3 where row != col {
                let factor = m[row][col] / m[col][col]
                for k in col..<4 {
                    m[row][k] -= factor * m[col][k]
                }
            }
        }
        return (m[0][3] / m[0][0], m[1][3] / m[1][1], m[2][3] / m[2][2])
    }

    // MARK: Вспомогательное

    private static func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { min(max(v, lo), hi) }
    private static func clamp01(_ v: Double) -> Double { min(max(v, 0.0), 1.0) }
}

/// Детерминированный генератор: один и тот же кадр всегда даёт один и тот же замер.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
