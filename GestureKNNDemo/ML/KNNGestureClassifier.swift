import Foundation

struct KNNGestureClassifier {
    struct Neighbor: Identifiable {
        let id = UUID()
        let label: String
        let distance: Double
    }

    struct Prediction {
        let label: String
        let confidence: Double
        let averageDistance: Double
        let nearestNeighbors: [Neighbor]
    }

    private static let minimumWholeGestureCoverage = 0.55
    private static let coveragePenaltyWeight = 1.5

    /// k-NN over raw motion sequences, using DTW as the distance metric.
    static func predictSequence(
        inputSamples: [MotionSample],
        examples: [GestureExample],
        k requestedK: Int = 3
    ) -> Prediction? {
        let usableExamples = examples.compactMap { example -> (label: String, samples: [MotionSample])? in
            guard let samples = example.samples, samples.count >= 15 else { return nil }
            return (label: example.label, samples: samples)
        }

        guard inputSamples.count >= 15, !usableExamples.isEmpty else { return nil }

        let comparableExamples = usableExamples.filter { example in
            wholeGestureCoverage(inputSamples, example.samples) >= minimumWholeGestureCoverage
        }

        guard !comparableExamples.isEmpty else { return nil }

        let k = max(1, min(requestedK, comparableExamples.count))
        let normalized = normalizeSequences(
            input: inputSamples,
            examples: comparableExamples.map(\.samples)
        )

        let distances = zip(comparableExamples, normalized.examples).map { example, normalizedSamples in
            let coverage = wholeGestureCoverage(inputSamples, example.samples)
            let coveragePenalty = (1 - coverage) * coveragePenaltyWeight

            return Neighbor(
                label: example.label,
                distance: dynamicTimeWarpingDistance(
                    normalized.input,
                    normalizedSamples
                ) + coveragePenalty
            )
        }

        let nearest = Array(distances.sorted { $0.distance < $1.distance }.prefix(k))
        return prediction(from: nearest, k: k)
    }

    /// Legacy feature-vector k-NN. Kept for debugging and future comparison against DTW.
    static func predict(
        inputFeatures: [Double],
        examples: [GestureExample],
        k requestedK: Int = 3
    ) -> Prediction? {
        guard !inputFeatures.isEmpty else { return nil }

        let usableExamples = examples.filter { $0.features.count == inputFeatures.count }
        guard !usableExamples.isEmpty else { return nil }

        let k = max(1, min(requestedK, usableExamples.count))

        let normalized = normalize(
            input: inputFeatures,
            examples: usableExamples.map(\.features)
        )

        let distances = zip(usableExamples, normalized.examples).map { example, normalizedFeatures in
            Neighbor(
                label: example.label,
                distance: euclideanDistance(normalized.input, normalizedFeatures)
            )
        }

        let nearest = Array(distances.sorted { $0.distance < $1.distance }.prefix(k))
        return prediction(from: nearest, k: k)
    }

    private static func prediction(from nearest: [Neighbor], k: Int) -> Prediction? {
        var labelStats: [String: (count: Int, totalDistance: Double)] = [:]

        for neighbor in nearest {
            let old = labelStats[neighbor.label] ?? (count: 0, totalDistance: 0)
            labelStats[neighbor.label] = (
                count: old.count + 1,
                totalDistance: old.totalDistance + neighbor.distance
            )
        }

        let rankedLabels = labelStats.map { label, stats in
            (
                label: label,
                count: stats.count,
                averageDistance: stats.totalDistance / Double(stats.count)
            )
        }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.averageDistance < rhs.averageDistance
            } else {
                return lhs.count > rhs.count
            }
        }

        guard let winner = rankedLabels.first else { return nil }

        return Prediction(
            label: winner.label,
            confidence: Double(winner.count) / Double(k),
            averageDistance: winner.averageDistance,
            nearestNeighbors: nearest
        )
    }

    private static func wholeGestureCoverage(_ input: [MotionSample], _ example: [MotionSample]) -> Double {
        min(durationCoverage(input, example), sampleCoverage(input, example))
    }

    private static func durationCoverage(_ input: [MotionSample], _ example: [MotionSample]) -> Double {
        let inputDuration = gestureDuration(input)
        let exampleDuration = gestureDuration(example)
        guard inputDuration > 0, exampleDuration > 0 else { return 0 }
        return min(inputDuration, exampleDuration) / max(inputDuration, exampleDuration)
    }

    private static func sampleCoverage(_ input: [MotionSample], _ example: [MotionSample]) -> Double {
        guard !input.isEmpty, !example.isEmpty else { return 0 }
        return Double(min(input.count, example.count)) / Double(max(input.count, example.count))
    }

    private static func gestureDuration(_ samples: [MotionSample]) -> TimeInterval {
        guard let first = samples.first, let last = samples.last else { return 0 }
        return max(last.timestamp - first.timestamp, 0)
    }

    private static func normalizeSequences(
        input: [MotionSample],
        examples: [[MotionSample]]
    ) -> (input: [[Double]], examples: [[[Double]]]) {
        let inputVectors = downsample(vectorize(input), maxCount: 160)
        let exampleVectors = examples.map { downsample(vectorize($0), maxCount: 160) }
        let allVectors = ([inputVectors] + exampleVectors).flatMap { $0 }
        let dimensionCount = 6

        let means = (0..<dimensionCount).map { dimension in
            allVectors.map { $0[dimension] }.reduce(0, +) / Double(max(allVectors.count, 1))
        }

        let stds = (0..<dimensionCount).map { dimension in
            let values = allVectors.map { $0[dimension] }
            let avg = means[dimension]
            let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Double(max(values.count, 1))
            let std = sqrt(variance)
            return std < 0.000001 ? 1.0 : std
        }

        func normalize(_ sequence: [[Double]]) -> [[Double]] {
            sequence.map { vector in
                vector.enumerated().map { dimension, value in
                    (value - means[dimension]) / stds[dimension]
                }
            }
        }

        return (
            input: normalize(inputVectors),
            examples: exampleVectors.map(normalize)
        )
    }

    private static func vectorize(_ samples: [MotionSample]) -> [[Double]] {
        samples.map { sample in
            [
                sample.ax,
                sample.ay,
                sample.az,
                sample.gx,
                sample.gy,
                sample.gz
            ]
        }
    }

    private static func downsample(_ vectors: [[Double]], maxCount: Int) -> [[Double]] {
        guard vectors.count > maxCount, maxCount > 1 else { return vectors }

        return (0..<maxCount).map { index in
            let sourceIndex = Int(
                (Double(index) / Double(maxCount - 1)) * Double(vectors.count - 1)
            )
            return vectors[sourceIndex]
        }
    }

    private static func dynamicTimeWarpingDistance(_ a: [[Double]], _ b: [[Double]]) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return .infinity }

        let rowCount = a.count
        let columnCount = b.count
        let window = max(abs(rowCount - columnCount), max(rowCount, columnCount) / 4)

        var previous = Array(repeating: Double.infinity, count: columnCount + 1)
        var current = Array(repeating: Double.infinity, count: columnCount + 1)
        previous[0] = 0

        for row in 1...rowCount {
            current = Array(repeating: Double.infinity, count: columnCount + 1)
            let startColumn = max(1, row - window)
            let endColumn = min(columnCount, row + window)

            if startColumn <= endColumn {
                for column in startColumn...endColumn {
                    let cost = euclideanDistance(a[row - 1], b[column - 1])
                    current[column] = cost + min(
                        previous[column],
                        current[column - 1],
                        previous[column - 1]
                    )
                }
            }

            previous = current
        }

        return previous[columnCount] / Double(rowCount + columnCount)
    }

    private static func normalize(
        input: [Double],
        examples: [[Double]]
    ) -> (input: [Double], examples: [[Double]]) {
        let featureCount = input.count
        let allVectors = examples + [input]

        let means = (0..<featureCount).map { featureIndex in
            allVectors.map { $0[featureIndex] }.reduce(0, +) / Double(allVectors.count)
        }

        let stds = (0..<featureCount).map { featureIndex in
            let values = allVectors.map { $0[featureIndex] }
            let avg = means[featureIndex]
            let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Double(values.count)
            let std = sqrt(variance)
            return std < 0.000001 ? 1.0 : std
        }

        func normalizeVector(_ vector: [Double]) -> [Double] {
            vector.enumerated().map { index, value in
                (value - means[index]) / stds[index]
            }
        }

        return (
            input: normalizeVector(input),
            examples: examples.map(normalizeVector)
        )
    }

    private static func euclideanDistance(_ a: [Double], _ b: [Double]) -> Double {
        zip(a, b)
            .map { lhs, rhs in pow(lhs - rhs, 2) }
            .reduce(0, +)
            .squareRoot()
    }
}
