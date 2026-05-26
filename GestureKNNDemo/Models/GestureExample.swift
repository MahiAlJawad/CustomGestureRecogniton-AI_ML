import Foundation

struct GestureExample: Identifiable, Codable {
    let id: UUID
    let label: String
    let features: [Double]
    let sampleCount: Int
    let createdAt: Date

    /// Raw samples are required by the DTW classifier. Older saved examples may not include them.
    let samples: [MotionSample]?

    init(label: String, features: [Double], samples: [MotionSample]) {
        self.id = UUID()
        self.label = label
        self.features = features
        self.sampleCount = samples.count
        self.createdAt = Date()
        self.samples = samples
    }
}
