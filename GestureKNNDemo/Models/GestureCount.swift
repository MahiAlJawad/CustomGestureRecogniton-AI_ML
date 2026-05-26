import Foundation

struct GestureCount: Identifiable {
    let id: String
    let label: String
    let count: Int

    init(label: String, count: Int) {
        self.id = label
        self.label = label
        self.count = count
    }
}
