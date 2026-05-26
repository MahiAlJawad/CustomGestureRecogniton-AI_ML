import SwiftUI

struct GestureRootView: View {
    @StateObject private var store = GestureStore()

    var body: some View {
        TabView {
            RecordGestureView(store: store)
                .tabItem {
                    Label("Register", systemImage: "record.circle")
                }

            DetectGestureView(store: store)
                .tabItem {
                    Label("Detect", systemImage: "waveform.path.ecg")
                }

            GestureLibraryView(store: store)
                .tabItem {
                    Label("Saved", systemImage: "tray.full")
                }
        }
    }
}

#Preview {
    GestureRootView()
}
