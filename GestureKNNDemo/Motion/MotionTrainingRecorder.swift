import CoreMotion
import Foundation
import SwiftUI

@MainActor
final class MotionTrainingRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var samples: [MotionSample] = []
    @Published var errorMessage: String?

    private let motionManager = CMMotionManager()
    private var baseTimestamp: TimeInterval?

    private let updateInterval: TimeInterval = 1.0 / 50.0

    func startRecording() {
        guard motionManager.isDeviceMotionAvailable else {
            errorMessage = "Device motion is not available on this device. Run on a real iPhone, not the Simulator."
            return
        }

        samples.removeAll()
        errorMessage = nil
        baseTimestamp = nil
        isRecording = true

        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }

            if let error {
                self.errorMessage = error.localizedDescription
                return
            }

            guard let motion else { return }

            if self.baseTimestamp == nil {
                self.baseTimestamp = motion.timestamp
            }

            let relativeTime = motion.timestamp - (self.baseTimestamp ?? motion.timestamp)
            let sample = MotionSample(
                ax: motion.userAcceleration.x,
                ay: motion.userAcceleration.y,
                az: motion.userAcceleration.z,
                gx: motion.rotationRate.x,
                gy: motion.rotationRate.y,
                gz: motion.rotationRate.z,
                timestamp: relativeTime
            )

            self.samples.append(sample)
        }
    }

    @discardableResult
    func stopRecording() -> [MotionSample] {
        motionManager.stopDeviceMotionUpdates()
        isRecording = false
        return samples
    }
}
