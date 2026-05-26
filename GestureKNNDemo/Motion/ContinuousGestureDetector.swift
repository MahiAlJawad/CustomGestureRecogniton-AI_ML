import CoreMotion
import Foundation
import SwiftUI

@MainActor
final class ContinuousGestureDetector: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var bufferedSampleCount = 0
    @Published private(set) var activeSegmentDuration: TimeInterval = 0
    @Published private(set) var latestPrediction: KNNGestureClassifier.Prediction?
    @Published private(set) var toastMessage: String?
    @Published private(set) var statusMessage = "Listen continuously and detect saved gestures."
    @Published var errorMessage: String?

    private let motionManager = CMMotionManager()
    private var toastTask: Task<Void, Never>?
    private var examples: [GestureExample] = []
    private var rollingBuffer: [MotionSample] = []
    private var candidateSamples: [MotionSample] = []
    private var baseTimestamp: TimeInterval?
    private var quietStartTime: TimeInterval?
    private var cooldownUntil: TimeInterval = 0

    private let updateInterval: TimeInterval = 1.0 / 50.0
    private let rollingBufferDuration: TimeInterval = 5.0
    private let minGestureDuration: TimeInterval = 0.35
    private let maxGestureDuration: TimeInterval = 4.5
    private let quietDurationToEndGesture: TimeInterval = 0.45
    private let cooldownDuration: TimeInterval = 1.5
    private let motionStartThreshold = 0.35
    private let motionEndThreshold = 0.18
    private let confidenceThreshold = 0.67
    private let maxAcceptedDistance = 1.25
    private let k = 3

    func startListening(examples: [GestureExample]) {
        guard motionManager.isDeviceMotionAvailable else {
            errorMessage = "Device motion is not available on this device. Run on a real iPhone, not the Simulator."
            return
        }

        guard !examples.isEmpty else {
            statusMessage = "Register gestures first."
            return
        }

        self.examples = examples
        rollingBuffer.removeAll()
        candidateSamples.removeAll()
        baseTimestamp = nil
        quietStartTime = nil
        cooldownUntil = 0
        bufferedSampleCount = 0
        activeSegmentDuration = 0
        latestPrediction = nil
        toastMessage = nil
        toastTask?.cancel()
        toastTask = nil
        errorMessage = nil
        statusMessage = "Listening..."
        isListening = true

        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }

            if let error {
                self.errorMessage = error.localizedDescription
                self.statusMessage = "Motion stream error."
                return
            }

            guard let motion else { return }
            self.handleMotion(motion)
        }
    }

    func stopListening() {
        guard isListening else { return }

        motionManager.stopDeviceMotionUpdates()
        isListening = false
        rollingBuffer.removeAll()
        candidateSamples.removeAll()
        toastTask?.cancel()
        toastTask = nil
        toastMessage = nil
        bufferedSampleCount = 0
        activeSegmentDuration = 0
        quietStartTime = nil
        statusMessage = latestPrediction == nil ? "Listening stopped." : "Listening stopped. Last gesture retained."
    }

    private func handleMotion(_ motion: CMDeviceMotion) {
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

        rollingBuffer.append(sample)
        trimRollingBuffer(currentTime: relativeTime)
        bufferedSampleCount = rollingBuffer.count

        if relativeTime < cooldownUntil {
            statusMessage = "Cooling down..."
            return
        }

        let intensity = motionIntensity(for: sample)

        if candidateSamples.isEmpty {
            activeSegmentDuration = 0

            if intensity >= motionStartThreshold {
                candidateSamples = [sample]
                quietStartTime = nil
                statusMessage = "Gesture movement detected..."
            } else {
                statusMessage = latestPrediction == nil ? "Listening..." : "Listening for next gesture..."
            }

            return
        }

        candidateSamples.append(sample)
        activeSegmentDuration = gestureDuration(candidateSamples)

        if activeSegmentDuration >= maxGestureDuration {
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
            statusMessage = "Capturing gesture..."
        }
    }

    private func finishCandidate() {
        let segment = candidateSamples
        candidateSamples.removeAll()
        quietStartTime = nil
        activeSegmentDuration = 0

        let duration = gestureDuration(segment)
        guard duration >= minGestureDuration else {
            statusMessage = "Movement was too short."
            return
        }

        guard let prediction = KNNGestureClassifier.predictSequence(
            inputSamples: segment,
            examples: examples,
            k: k
        ) else {
            statusMessage = "No complete DTW match found."
            return
        }

        guard prediction.confidence >= confidenceThreshold else {
            statusMessage = "Gesture ignored: confidence \(Int(prediction.confidence * 100))%."
            return
        }

        guard prediction.averageDistance <= maxAcceptedDistance else {
            statusMessage = "Gesture ignored: match distance \(prediction.averageDistance.formatted(.number.precision(.fractionLength(2))))."
            return
        }

        latestPrediction = prediction
        cooldownUntil = (segment.last?.timestamp ?? 0) + cooldownDuration
        statusMessage = "Detected \(prediction.label)."
        showToast("Detected \(prediction.label)")
    }

    private func trimRollingBuffer(currentTime: TimeInterval) {
        let cutoff = currentTime - rollingBufferDuration
        rollingBuffer.removeAll { $0.timestamp < cutoff }
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

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.3))
            toastMessage = nil
            toastTask = nil
        }
    }
}
