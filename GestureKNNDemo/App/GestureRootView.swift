import SwiftUI

struct GestureRootView: View {
    @StateObject private var store = GestureStore()
    @AppStorage(GestureLaunchPreferences.selectedTabKey) private var selectedTab = GestureAppTab.register.rawValue

    var body: some View {
        TabView(selection: $selectedTab) {
            RecordGestureView(store: store)
                .tabItem {
                    Label("Register", systemImage: "record.circle")
                }
                .tag(GestureAppTab.register.rawValue)

            DetectGestureView(store: store)
                .tabItem {
                    Label("Detect", systemImage: "waveform.path.ecg")
                }
                .tag(GestureAppTab.detect.rawValue)

            GestureLibraryView(store: store)
                .tabItem {
                    Label("Saved", systemImage: "tray.full")
                }
                .tag(GestureAppTab.saved.rawValue)

            TrainDataView()
                .tabItem {
                    Label("Train Data", systemImage: "externaldrive.badge.plus")
                }
                .tag(GestureAppTab.trainData.rawValue)
        }
        .task {
            await GestureNotificationManager.requestAuthorizationIfNeeded()
        }
    }
}

#Preview {
    GestureRootView()
}
