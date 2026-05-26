import Foundation

struct MotionSample: Codable {
    let ax: Double
    let ay: Double
    let az: Double

    let gx: Double
    let gy: Double
    let gz: Double

    /// Relative timestamp in seconds from the beginning of this recording.
    let timestamp: TimeInterval
}
