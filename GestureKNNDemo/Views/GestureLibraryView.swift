import SwiftUI

struct GestureLibraryView: View {
    @ObservedObject var store: GestureStore
    @State private var showDeleteAllAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    if store.gestureCounts.isEmpty {
                        Text("No gestures saved.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.gestureCounts) { item in
                            HStack {
                                Text(item.label)
                                Spacer()
                                Text("\(item.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: store.deleteGestures)
                    }
                }

                Section("All Examples") {
                    ForEach(store.examples) { example in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(example.label)
                                .fontWeight(.semibold)

                            Text("Samples: \(example.sampleCount) • Features: \(example.features.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(example.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                store.deleteGestureExample(id: example.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: store.deleteExamples)
                }
            }
            .navigationTitle("Saved Gestures")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .disabled(store.examples.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        showDeleteAllAlert = true
                    }
                    .disabled(store.examples.isEmpty)
                }
            }
            .alert("Delete all saved gestures?", isPresented: $showDeleteAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    store.deleteAll()
                }
            }
        }
    }
}
