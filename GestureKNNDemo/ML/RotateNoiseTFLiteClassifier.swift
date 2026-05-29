import Foundation
import TensorFlowLite

struct RotateNoiseTFLiteClassifier {
    struct Prediction {
        let label: String
        let rotateProbability: Float

        var isRotate: Bool {
            label == "rotate"
        }
    }

    enum ClassifierError: LocalizedError {
        case modelNotFound
        case labelsNotFound
        case invalidLabels
        case invalidOutput

        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "Rotate/noise TFLite model was not found in the app bundle."
            case .labelsNotFound:
                return "Rotate/noise labels file was not found in the app bundle."
            case .invalidLabels:
                return "Rotate/noise labels must contain noise and rotate."
            case .invalidOutput:
                return "Rotate/noise model returned an unreadable output."
            }
        }
    }

    private static let windowSize = 64
    private static let featureCount = 6
    private static let rotateThreshold: Float = 0.5

    private var interpreter: Interpreter
    private let labels: [String]

    init() throws {
        guard let modelPath = Bundle.main.path(
            forResource: "gesture_rotate_model",
            ofType: "tflite"
        ) else {
            throw ClassifierError.modelNotFound
        }

        guard let labelsURL = Bundle.main.url(
            forResource: "labels",
            withExtension: "txt"
        ) else {
            throw ClassifierError.labelsNotFound
        }

        labels = try String(contentsOf: labelsURL)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard labels.contains("noise"), labels.contains("rotate") else {
            throw ClassifierError.invalidLabels
        }

        var options = Interpreter.Options()
        options.threadCount = 1

        interpreter = try Interpreter(modelPath: modelPath, options: options)
        try interpreter.allocateTensors()
    }

    mutating func predict(samples: [MotionSample]) throws -> Prediction? {
        guard samples.count >= 2 else { return nil }

        let inputValues = Self.resampledWindow(from: samples)
        let inputData = inputValues.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }

        try interpreter.copy(inputData, toInputAt: 0)
        try interpreter.invoke()

        let output = try interpreter.output(at: 0)
        let probabilities = output.data.toArray(type: Float32.self)

        guard let rotateProbability = probabilities.first else {
            throw ClassifierError.invalidOutput
        }

        let label = rotateProbability >= Self.rotateThreshold ? "rotate" : "noise"

        return Prediction(
            label: label,
            rotateProbability: rotateProbability
        )
    }

    private static func resampledWindow(from samples: [MotionSample]) -> [Float32] {
        (0..<windowSize).flatMap { index -> [Float32] in
            let sourceIndex = Int(
                (Double(index) / Double(windowSize - 1)) * Double(samples.count - 1)
            )
            let sample = samples[sourceIndex]

            return [
                Float32(sample.ax),
                Float32(sample.ay),
                Float32(sample.az),
                Float32(sample.gx),
                Float32(sample.gy),
                Float32(sample.gz)
            ]
        }
    }
}

private extension Data {
    func toArray<T>(type: T.Type) -> [T] {
        withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return [] }
            let typedPointer = baseAddress.assumingMemoryBound(to: T.self)
            let count = self.count / MemoryLayout<T>.stride
            return Array(UnsafeBufferPointer(start: typedPointer, count: count))
        }
    }
}
