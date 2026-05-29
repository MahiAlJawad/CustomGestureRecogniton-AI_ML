import SwiftUI

struct TrainDataView: View {
    private let labels = ["idle", "noise", "rotate"]
    private let minimumSampleCount = 25

    @StateObject private var recorder = MotionTrainingRecorder()
    @State private var selectedLabel = "idle"
    @State private var lastSavedFile: TrainingCSVFile?
    @State private var recentFiles: [TrainingCSVFile] = []
    @State private var statusMessage = "Collect raw CoreMotion CSV files for later TFLite training on your Mac."

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This tab records raw accelerometer and gyroscope samples only. Export these CSV files to your Mac and train the TFLite model there.")
                        .foregroundStyle(.secondary)
                }

                Section("Label") {
                    Picker("Training Label", selection: $selectedLabel) {
                        ForEach(labels, id: \.self) { label in
                            Text(label).tag(label)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(recorder.isRecording)
                }

                Section("Recording") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(recorder.isRecording ? "Recording \(selectedLabel) samples..." : statusMessage)
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
                                Text(recorder.isRecording ? "Stop Recording" : "Start Recording")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if let error = recorder.errorMessage {
                    Section("Motion Error") {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                if let lastSavedFile {
                    Section("Last Saved CSV") {
                        TrainingFileDetailView(file: lastSavedFile)
                    }
                }

                Section("Share CSV Groups") {
                    ForEach(labels, id: \.self) { label in
                        let files = recentFiles.filter { $0.label == label }

                        if files.isEmpty {
                            LabeledContent(label, value: "No files")
                                .foregroundStyle(.secondary)
                        } else {
                            ShareLink(items: files.map(\.url)) {
                                Label("Share all \(label)", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }

                Section("Recent CSV Files") {
                    if recentFiles.isEmpty {
                        Text("No CSV files saved yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentFiles) { file in
                            TrainingFileRow(file: file)
                        }
                        .onDelete(perform: deleteRecentFiles)
                    }
                }
            }
            .navigationTitle("Train Data")
            .onAppear(perform: loadRecentFiles)
        }
    }

    private func handleRecordButton() {
        if recorder.isRecording {
            saveRecording()
        } else {
            lastSavedFile = nil
            statusMessage = "Recording..."
            recorder.startRecording()
        }
    }

    private func saveRecording() {
        let samples = recorder.stopRecording()

        guard samples.count >= minimumSampleCount else {
            statusMessage = "Too few samples. Record for at least half a second."
            return
        }

        do {
            let savedFile = try TrainingCSVStore.save(samples: samples, label: selectedLabel)
            lastSavedFile = savedFile
            statusMessage = "Saved \(savedFile.fileName)."
            loadRecentFiles()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func loadRecentFiles() {
        recentFiles = TrainingCSVStore.recentFiles()
    }

    private func deleteRecentFiles(at offsets: IndexSet) {
        let filesToDelete = offsets.map { recentFiles[$0] }

        do {
            try TrainingCSVStore.delete(files: filesToDelete)

            if let lastSavedFile, filesToDelete.contains(where: { $0.id == lastSavedFile.id }) {
                self.lastSavedFile = nil
            }

            statusMessage = "Deleted \(filesToDelete.count) CSV file\(filesToDelete.count == 1 ? "" : "s")."
            loadRecentFiles()
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private struct TrainingFileDetailView: View {
    let file: TrainingCSVFile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("File", value: file.fileName)
            LabeledContent("Samples", value: "\(file.sampleCount)")

            Text(file.url.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            ShareLink(item: file.url) {
                Label("Share CSV", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct TrainingFileRow: View {
    let file: TrainingCSVFile

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .font(.subheadline)
                    .lineLimit(1)

                Text("\(file.sampleCount) samples")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ShareLink(item: file.url) {
                Image(systemName: "square.and.arrow.up")
                    .imageScale(.medium)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Share \(file.fileName)")
        }
    }
}

private struct TrainingCSVFile: Identifiable {
    let url: URL
    let sampleCount: Int

    var id: URL { url }
    var fileName: String { url.lastPathComponent }
    var label: String { fileName.split(separator: "_").first.map(String.init) ?? "" }
}

private enum TrainingCSVStore {
    private static let header = "timestamp,ax,ay,az,gx,gy,gz,label"
    private static let allowedLabels = ["idle", "noise", "rotate"]

    static func save(samples: [MotionSample], label: String) throws -> TrainingCSVFile {
        let fileURL = documentsDirectory()
            .appendingPathComponent("\(label)_\(fileTimestamp()).csv")

        let rows = samples.map { sample in
            [
                format(sample.timestamp),
                format(sample.ax),
                format(sample.ay),
                format(sample.az),
                format(sample.gx),
                format(sample.gy),
                format(sample.gz),
                label
            ].joined(separator: ",")
        }

        let csv = ([header] + rows).joined(separator: "\n") + "\n"
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)

        return TrainingCSVFile(url: fileURL, sampleCount: samples.count)
    }

    static func recentFiles() -> [TrainingCSVFile] {
        let directory = documentsDirectory()
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { isTrainingCSV($0) }
            .sorted { lhs, rhs in
                modificationDate(for: lhs) > modificationDate(for: rhs)
            }
            .map { url in
                TrainingCSVFile(url: url, sampleCount: sampleCount(in: url))
            }
    }

    static func delete(files: [TrainingCSVFile]) throws {
        for file in files {
            try FileManager.default.removeItem(at: file.url)
        }
    }

    private static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func isTrainingCSV(_ url: URL) -> Bool {
        guard url.pathExtension == "csv" else { return false }

        let fileName = url.deletingPathExtension().lastPathComponent
        return allowedLabels.contains { label in
            fileName.hasPrefix("\(label)_")
        }
    }

    private static func sampleCount(in url: URL) -> Int {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return 0
        }

        return max(contents.split(separator: "\n").count - 1, 0)
    }

    private static func modificationDate(for url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? .distantPast
    }

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
