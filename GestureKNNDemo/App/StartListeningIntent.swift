import AppIntents
import Foundation

struct StartListeningIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Listening"
    static var description = IntentDescription("Listen briefly for a saved gesture in the background.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let examples = GestureStore.loadSavedExamples()
        let listener = BackgroundGestureListener()

        if let prediction = await listener.listenForFirstGesture(examples: examples, timeout: .seconds(12)) {
            await GestureNotificationManager.notifyDetectedGesture(prediction.label)
            return .result(dialog: "Detected \(prediction.label)")
        }

        return .result(dialog: "No gesture detected")
    }
}

struct GestureAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartListeningIntent(),
            phrases: [
                "Start listening in \(.applicationName)",
                "Start gesture detection in \(.applicationName)"
            ],
            shortTitle: "Start Listening",
            systemImageName: "waveform.path.ecg"
        )
    }
}
