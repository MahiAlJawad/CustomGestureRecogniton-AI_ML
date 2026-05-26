import Foundation

enum GestureAppTab: String {
    case register
    case detect
    case saved
}

enum GestureLaunchPreferences {
    static let selectedTabKey = "selected_gesture_app_tab"
    static let shouldStartListeningKey = "should_start_gesture_listening"
}
