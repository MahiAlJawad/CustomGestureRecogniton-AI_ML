import Foundation

enum GestureDemoError: LocalizedError {
    case emptyGestureName
    case notEnoughMotionData

    var errorDescription: String? {
        switch self {
        case .emptyGestureName:
            return "Enter a gesture name first."
        case .notEnoughMotionData:
            return "Not enough motion data. Record for at least half a second."
        }
    }
}
