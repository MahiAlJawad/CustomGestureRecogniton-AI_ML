import SwiftUI

struct RecordGestureView: View {
    @ObservedObject var store: GestureStore
    @StateObject private var recorder = MotionRecorder()

    @State private var gestureName = ""
    @State private var statusMessage = "Record at least 3 examples for each gesture."
    @FocusState private var isGestureNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Gesture Name") {
                    TextField("Example: Dim Light", text: $gestureName)
                        .textInputAutocapitalization(.words)
                        .focused($isGestureNameFocused)
                }

                Section("Record Example") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(recorder.isRecording ? "Recording... perform the gesture now." : statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(recorder.isRecording ? .red : .secondary)

                        Text("Samples: \(recorder.samples.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            handleRecordButton()
                        } label: {
                            HStack {
                                Image(systemName: recorder.isRecording ? "stop.fill" : "record.circle")
                                Text(recorder.isRecording ? "Stop & Save Example" : "Start Recording")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!recorder.isRecording && gestureName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if let error = recorder.errorMessage {
                    Section("Motion Error") {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section("Saved Training Data") {
                    if store.gestureCounts.isEmpty {
                        Text("No saved gestures yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.gestureCounts) { item in
                            HStack {
                                Text(item.label)
                                Spacer()
                                Text("\(item.count) example\(item.count == 1 ? "" : "s")")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Register Gesture")
        }
    }

    private func handleRecordButton() {
        if recorder.isRecording {
            let samples = recorder.stopRecording()

            do {
                try store.addGestureExample(label: gestureName, samples: samples)
                statusMessage = "Saved. Record more examples for better accuracy."
            } catch {
                statusMessage = error.localizedDescription
            }
        } else {
            isGestureNameFocused = false
            statusMessage = "Recording..."
            recorder.startRecording()
        }
    }
}
