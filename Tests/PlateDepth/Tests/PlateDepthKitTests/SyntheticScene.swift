import Foundation
@testable import PlateDepthKit

/// Воксельно-точный рендер глубины: стол — плоскость z = a·x + b·y + c (система камеры),
/// на нём стоят цилиндры (посуда/еда). Луч идёт шагом в полмиллиметра и ищет первое попадание.
struct SyntheticScene {
    struct Cylinder {
        var centerU: Double      // смещение центра вдоль оси e1 плоскости, м
        var centerV: Double      // вдоль e2, м
        var radius: Double
        var height: Double
    }

    var a: Double = 0
    var b: Double = 0
    var c: Double = 0.40
    var cylinders: [Cylinder] = []

    // Камера: 384×288, горизонтальный угол обзора 63°
    let width = 384
    let height = 288
    var fx: Double { (Double(width) / 2.0) / tan(63.0 * .pi / 360.0) }
    var fy: Double { fx }
    var cx: Double { Double(width) / 2.0 }
    var cy: Double { Double(height) / 2.0 }

    private var norm: Double { (1 + a * a + b * b).squareRoot() }
    /// Единичная нормаль «вверх» (к камере).
    private var up: (Double, Double, Double) { (a / norm, b / norm, -1 / norm) }

    private var basis: ((Double, Double, Double), (Double, Double, Double)) {
        let n = up
        // e1 ⟂ n, берём из векторного произведения с осью X камеры, если она не параллельна
        var e1 = cross(n, (1, 0, 0))
        if length(e1) < 1e-6 { e1 = cross(n, (0, 1, 0)) }
        e1 = scale(e1, 1 / length(e1))
        let e2 = cross(n, e1)
        return (e1, scale(e2, 1 / length(e2)))
    }

    func render(noiseSigma: Double = 0, dropoutFraction: Double = 0, seed: UInt64 = 7) -> [Float] {
        var rng = SplitMix64(seed: seed)
        func uniform() -> Double { Double(rng.next() >> 11) / Double(1 << 53) }
        func gaussian() -> Double {
            let u1 = max(uniform(), 1e-12), u2 = uniform()
            return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
        }

        let (e1, e2) = basis
        let n = up
        let origin = (0.0, 0.0, c)
        var out = [Float](repeating: .nan, count: width * height)

        for py in 0..<height {
            for px in 0..<width {
                let dx = (Double(px) + 0.5 - cx) / fx
                let dy = (Double(py) + 0.5 - cy) / fy
                let denom = 1 - a * dx - b * dy
                guard denom > 0.05 else { continue }
                let tTable = c / denom

                var depth = tTable
                if !cylinders.isEmpty {
                    var t = max(0.05, tTable - 0.14)
                    let step = 0.0005
                    while t < tTable {
                        let p = (dx * t, dy * t, t)
                        let rel = (p.0 - origin.0, p.1 - origin.1, p.2 - origin.2)
                        let h = dot(rel, n)
                        if h >= 0 {
                            let u = dot(rel, e1), v = dot(rel, e2)
                            if cylinders.contains(where: { cyl in
                                h <= cyl.height && hypot(u - cyl.centerU, v - cyl.centerV) <= cyl.radius
                            }) {
                                depth = t
                                break
                            }
                        }
                        t += step
                    }
                }

                if dropoutFraction > 0, uniform() < dropoutFraction { continue }
                if noiseSigma > 0 { depth += noiseSigma * gaussian() }
                out[py * width + px] = Float(depth)
            }
        }
        return out
    }

    func grid(meters: [Float], absolute: Bool = true, highQuality: Bool = true) -> PlateDepthGrid {
        PlateDepthGrid(width: width, height: height, meters: meters,
                       fx: fx, fy: fy, cx: cx, cy: cy,
                       hasAbsoluteScale: absolute, isHighQuality: highQuality)
    }
}

private func dot(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double { a.0 * b.0 + a.1 * b.1 + a.2 * b.2 }
private func cross(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> (Double, Double, Double) {
    (a.1 * b.2 - a.2 * b.1, a.2 * b.0 - a.0 * b.2, a.0 * b.1 - a.1 * b.0)
}
private func length(_ a: (Double, Double, Double)) -> Double { dot(a, a).squareRoot() }
private func scale(_ a: (Double, Double, Double), _ s: Double) -> (Double, Double, Double) { (a.0 * s, a.1 * s, a.2 * s) }
