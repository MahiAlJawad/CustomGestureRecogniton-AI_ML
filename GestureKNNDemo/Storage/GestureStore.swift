import Foundation
import SwiftUI

@MainActor
final class GestureStore: ObservableObject {
    @Published private(set) var examples: [GestureExample] = []

    static let storageKey = "gesture_examples_knn_v1"

    init() {
        load()
    }

    var gestureCounts: [GestureCount] {
        let grouped = Dictionary(grouping: examples, by: { $0.label })
        return grouped
            .map { GestureCount(label: $0.key, count: $0.value.count) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    func addGestureExample(label rawLabel: String, samples: [MotionSample]) throws {
        let label = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !label.isEmpty else {
            throw GestureDemoError.emptyGestureName
        }

        guard let features = GestureFeatureExtractor.extractFeatures(from: samples) else {
            throw GestureDemoError.notEnoughMotionData
        }

        let example = GestureExample(
            label: label,
            features: features,
            samples: samples
        )

        examples.append(example)
        save()
    }

    func deleteExamples(at offsets: IndexSet) {
        examples.remove(atOffsets: offsets)
        save()
    }

    func deleteGestures(at offsets: IndexSet) {
        let labelsToDelete = Set(offsets.map { gestureCounts[$0].label })
        examples.removeAll { labelsToDelete.contains($0.label) }
        save()
    }

    func deleteGestureExample(id: GestureExample.ID) {
        examples.removeAll { $0.id == id }
        save()
    }

    func deleteAll() {
        examples.removeAll()
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(examples)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            print("Failed to save gesture examples:", error)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }

        do {
            examples = try JSONDecoder().decode([GestureExample].self, from: data)
        } catch {
            print("Failed to load gesture examples:", error)
            examples = []
        }
    }

    static func loadSavedExamples() -> [GestureExample] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }

        do {
            return try JSONDecoder().decode([GestureExample].self, from: data)
        } catch {
            print("Failed to load gesture examples:", error)
            return []
        }
    }
}
