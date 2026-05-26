import Foundation

/// Converts raw CoreMotion samples into a fixed-size feature vector.
/// The feature vector remains useful for storage metadata and fallback experiments.
enum GestureFeatureExtractor {
    static func extractFeatures(from samples: [MotionSample]) -> [Double]? {
        guard samples.count >= 15 else { return nil }
        guard let first = samples.first, let last = samples.last else { return nil }

        let duration = max(last.timestamp - first.timestamp, 0.001)

        let accelMagnitudes = samples.map {
            magnitude($0.ax, $0.ay, $0.az)
        }

        let gyroMagnitudes = samples.map {
            magnitude($0.gx, $0.gy, $0.gz)
        }

        let accelX = samples.map(\.ax)
        let accelY = samples.map(\.ay)
        let accelZ = samples.map(\.az)

        let gyroX = samples.map(\.gx)
        let gyroY = samples.map(\.gy)
        let gyroZ = samples.map(\.gz)

        let dominantAccelAxis = dominantAxis(x: accelX, y: accelY, z: accelZ)
        let dominantGyroAxis = dominantAxis(x: gyroX, y: gyroY, z: gyroZ)

        let accelPeaks = peakCount(values: accelMagnitudes, threshold: 0.25)
        let gyroPeaks = peakCount(values: gyroMagnitudes, threshold: 1.0)

        return [
            duration,

            mean(accelMagnitudes),
            maxValue(accelMagnitudes),
            standardDeviation(accelMagnitudes),
            rms(accelMagnitudes),
            accelPeaks,
            dominantAccelAxis,

            mean(gyroMagnitudes),
            maxValue(gyroMagnitudes),
            standardDeviation(gyroMagnitudes),
            rms(gyroMagnitudes),
            gyroPeaks,
            dominantGyroAxis
        ]
    }

    private static func magnitude(_ x: Double, _ y: Double, _ z: Double) -> Double {
        sqrt(x * x + y * y + z * z)
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func maxValue(_ values: [Double]) -> Double {
        values.max() ?? 0
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let avg = mean(values)
        let variance = values
            .map { pow($0 - avg, 2) }
            .reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }

    private static func rms(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let meanSquare = values
            .map { $0 * $0 }
            .reduce(0, +) / Double(values.count)
        return sqrt(meanSquare)
    }

    private static func dominantAxis(x: [Double], y: [Double], z: [Double]) -> Double {
        let xPower = x.map(abs).reduce(0, +)
        let yPower = y.map(abs).reduce(0, +)
        let zPower = z.map(abs).reduce(0, +)

        let values = [xPower, yPower, zPower]
        let maxIndex = values.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0

        return Double(maxIndex)
    }

    private static func peakCount(values: [Double], threshold: Double) -> Double {
        guard values.count >= 3 else { return 0 }

        var count = 0

        for index in 1..<(values.count - 1) {
            let previous = values[index - 1]
            let current = values[index]
            let next = values[index + 1]

            if current > previous, current > next, current >= threshold {
                count += 1
            }
        }

        return Double(count)
    }
}
