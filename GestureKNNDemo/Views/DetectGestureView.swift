import SwiftUI

struct DetectGestureView: View {
    @ObservedObject var store: GestureStore
    @StateObject private var detector = ContinuousGestureDetector()
    @AppStorage(GestureLaunchPreferences.shouldStartListeningKey) private var shouldStartListening = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Form {
                    Section("Continuous Detection") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(detector.statusMessage)
                                .font(.subheadline)
                                .foregroundStyle(detector.isListening ? .blue : .secondary)

                            Text("Buffered samples: \(detector.bufferedSampleCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if detector.activeSegmentDuration > 0 {
                                Text("Current gesture: \(detector.activeSegmentDuration.formatted(.number.precision(.fractionLength(1))))s")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                handleListeningButton()
                            } label: {
                                HStack {
                                    Image(systemName: detector.isListening ? "stop.circle.fill" : "waveform.path.ecg")
                                    Text(detector.isListening ? "Stop Listening" : "Start Listening")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!detector.isListening && store.examples.isEmpty)
                        }
                    }

                    Section("Prediction") {
                        if let prediction = detector.latestPrediction {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Last Detected")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(prediction.label)
                                        .fontWeight(.semibold)
                                }

                                HStack {
                                    Text("Vote Confidence")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(prediction.confidence * 100))%")
                                        .fontWeight(.semibold)
                                }

                                HStack {
                                    Text("Average Distance")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(prediction.averageDistance.formatted(.number.precision(.fractionLength(3))))
                                        .fontWeight(.semibold)
                                }
                            }
                        } else {
                            Text(store.examples.isEmpty ? "Register gestures first." : "No gesture detected yet.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let prediction = detector.latestPrediction {
                        Section("Nearest Saved Examples") {
                            ForEach(prediction.nearestNeighbors) { neighbor in
                                HStack {
                                    Text(neighbor.label)
                                    Spacer()
                                    Text(neighbor.distance.formatted(.number.precision(.fractionLength(3))))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if let error = detector.errorMessage {
                        Section("Motion Error") {
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                }

                if let toastMessage = detector.toastMessage {
                    Text(toastMessage)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.blue, in: Capsule())
                        .shadow(radius: 8, y: 4)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .allowsHitTesting(false)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: detector.toastMessage)
            .navigationTitle("Detect Gesture")
            .onAppear {
                handlePendingListeningRequest()
            }
            .onChange(of: shouldStartListening) {
                handlePendingListeningRequest()
            }
            .onDisappear {
                detector.stopListening()
            }
        }
    }

    private func handleListeningButton() {
        if detector.isListening {
            detector.stopListening()
        } else {
            detector.startListening(examples: store.examples)
        }
    }

    private func handlePendingListeningRequest() {
        guard shouldStartListening else { return }

        shouldStartListening = false

        if !detector.isListening {
            detector.startListening(examples: store.examples)
        }
    }
}
