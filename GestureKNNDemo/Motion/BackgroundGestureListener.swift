import CoreMotion
import Foundation

@MainActor
final class BackgroundGestureListener {
    private let motionManager = CMMotionManager()
    private var examples: [GestureExample] = []
    private var candidateSamples: [MotionSample] = []
    private var baseTimestamp: TimeInterval?
    private var quietStartTime: TimeInterval?
    private var detectedPrediction: KNNGestureClassifier.Prediction?

    private let updateInterval: TimeInterval = 1.0 / 50.0
    private let minGestureDuration: TimeInterval = 0.35
    private let maxGestureDuration: TimeInterval = 4.5
    private let quietDurationToEndGesture: TimeInterval = 0.45
    private let motionStartThreshold = 0.35
    private let motionEndThreshold = 0.18
    private let confidenceThreshold = 0.67
    private let maxAcceptedDistance = 1.25
    private let k = 3

    func listenForFirstGesture(examples: [GestureExample], timeout: Duration = .seconds(12)) async -> KNNGestureClassifier.Prediction? {
        guard motionManager.isDeviceMotionAvailable, !examples.isEmpty else { return nil }

        self.examples = examples
        candidateSamples.removeAll()
        baseTimestamp = nil
        quietStartTime = nil
        detectedPrediction = nil

        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }

            Task { @MainActor in
                self.handleMotion(motion)
            }
        }

        defer {
            motionManager.stopDeviceMotionUpdates()
        }

        let deadline = ContinuousClock.now.advanced(by: timeout)

        while ContinuousClock.now < deadline, detectedPrediction == nil, !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                break
            }
        }

        return detectedPrediction
    }

    private func handleMotion(_ motion: CMDeviceMotion) {
        guard detectedPrediction == nil else { return }

        if baseTimestamp == nil {
            baseTimestamp = motion.timestamp
        }

        let relativeTime = motion.timestamp - (baseTimestamp ?? motion.timestamp)
        let sample = MotionSample(
            ax: motion.userAcceleration.x,
            ay: motion.userAcceleration.y,
            az: motion.userAcceleration.z,
            gx: motion.rotationRate.x,
            gy: motion.rotationRate.y,
            gz: motion.rotationRate.z,
            timestamp: relativeTime
        )

        let intensity = motionIntensity(for: sample)

        if candidateSamples.isEmpty {
            if intensity >= motionStartThreshold {
                candidateSamples = [sample]
                quietStartTime = nil
            }

            return
        }

        candidateSamples.append(sample)

        if gestureDuration(candidateSamples) >= maxGestureDuration {
            finishCandidate()
            return
        }

        if intensity <= motionEndThreshold {
            quietStartTime = quietStartTime ?? relativeTime

            if let quietStartTime, relativeTime - quietStartTime >= quietDurationToEndGesture {
                finishCandidate()
            }
        } else {
            quietStartTime = nil
        }
    }

    private func finishCandidate() {
        let segment = candidateSamples
        candidateSamples.removeAll()
        quietStartTime = nil

        guard gestureDuration(segment) >= minGestureDuration else { return }

        guard let prediction = KNNGestureClassifier.predictSequence(
            inputSamples: segment,
            examples: examples,
            k: k
        ) else {
            return
        }

        guard prediction.confidence >= confidenceThreshold else { return }
        guard prediction.averageDistance <= maxAcceptedDistance else { return }

        detectedPrediction = prediction
    }

    private func gestureDuration(_ samples: [MotionSample]) -> TimeInterval {
        guard let first = samples.first, let last = samples.last else { return 0 }
        return max(last.timestamp - first.timestamp, 0)
    }

    private func motionIntensity(for sample: MotionSample) -> Double {
        let acceleration = sqrt(sample.ax * sample.ax + sample.ay * sample.ay + sample.az * sample.az)
        let rotation = sqrt(sample.gx * sample.gx + sample.gy * sample.gy + sample.gz * sample.gz)
        return acceleration + (rotation * 0.12)
    }
}
