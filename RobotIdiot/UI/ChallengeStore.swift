import Foundation
import RobotIdiotCore

struct ChallengeEntry: Codable, Hashable {
    var id: UUID
    var createdAt: Date
    var recipe: ChallengeRecipe
    var level: Level
    var score: LevelScore?
}

struct ChallengeArchive: Codable {
    var entries: [ChallengeEntry]
}

final class ChallengeStore {
    static let shared = ChallengeStore()

    private let lock = NSLock()
    private var archive: ChallengeArchive
    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RobotIdiot", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("challenges.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(ChallengeArchive.self, from: data) {
            archive = decoded
        } else {
            archive = ChallengeArchive(entries: [])
            persistLocked()
        }
    }

    func entries() -> [ChallengeEntry] {
        lock.lock()
        defer { lock.unlock() }
        return archive.entries.sorted { $0.createdAt > $1.createdAt }
    }

    func entry(_ id: UUID) -> ChallengeEntry? {
        lock.lock()
        defer { lock.unlock() }
        return archive.entries.first { $0.id == id }
    }

    @discardableResult
    func append(level: Level, recipe: ChallengeRecipe) -> ChallengeEntry {
        let entry = ChallengeEntry(
            id: UUID(),
            createdAt: Date(),
            recipe: recipe,
            level: level,
            score: nil
        )
        lock.lock()
        archive.entries.append(entry)
        persistLocked()
        lock.unlock()
        return entry
    }

    func record(_ score: LevelScore, id: UUID) {
        lock.lock()
        guard let index = archive.entries.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return
        }
        if let existing = archive.entries[index].score, !score.isBetter(than: existing) {
            lock.unlock()
            return
        }
        archive.entries[index].score = score
        persistLocked()
        lock.unlock()
    }

    func delete(_ id: UUID) {
        lock.lock()
        archive.entries.removeAll { $0.id == id }
        persistLocked()
        lock.unlock()
    }

    func reset() {
        lock.lock()
        archive = ChallengeArchive(entries: [])
        persistLocked()
        lock.unlock()
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(archive) else { return }
        let temporary = fileURL.appendingPathExtension("tmp")
        try? data.write(to: temporary, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: temporary)
        } else {
            try? FileManager.default.moveItem(at: temporary, to: fileURL)
        }
    }
}
