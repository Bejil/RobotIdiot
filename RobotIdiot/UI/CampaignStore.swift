import Foundation
import RobotIdiotCore

struct ArchivedLevel: Codable {
    var address: LevelAddress
    var level: Level
}

struct CampaignArchive: Codable {
    var progress: CampaignProgress
    var levels: [ArchivedLevel]
}

final class CampaignStore {
    static let shared = CampaignStore()

    private let lock = NSLock()
    private var archive: CampaignArchive
    private let fileURL: URL
    private let queue = DispatchQueue(label: "robotidiot.campaign", qos: .userInitiated)

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RobotIdiot", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("campaign.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(CampaignArchive.self, from: data) {
            archive = decoded
        } else {
            archive = CampaignArchive(
                progress: CampaignProgress(campaignSeed: UInt64.random(in: 1...UInt64.max)),
                levels: []
            )
            persistLocked()
        }
        if archive.progress.formulaVersion < WorldGenerator.formulaVersion {
            archive.progress.formulaVersion = WorldGenerator.formulaVersion
            persistLocked()
        }
    }

    func progress() -> CampaignProgress {
        lock.lock()
        defer { lock.unlock() }
        return archive.progress
    }

    func record(_ score: LevelScore, at address: LevelAddress) {
        lock.lock()
        CampaignRules.record(score, at: address, in: &archive.progress)
        persistLocked()
        lock.unlock()
    }

    func level(at address: LevelAddress) -> Level? {
        lock.lock()
        defer { lock.unlock() }
        return archive.levels.first { $0.address == address }?.level
    }

    func materialize(_ address: LevelAddress, completion: @escaping (Level) -> Void) {
        queue.async {
            let level = self.materializeSync(address)
            DispatchQueue.main.async {
                completion(level)
            }
        }
    }

    func warm(_ address: LevelAddress) {
        queue.async {
            _ = self.materializeSync(address)
        }
    }

    private func materializeSync(_ address: LevelAddress) -> Level {
        if let stored = level(at: address) { return stored }
        let seed = progress().campaignSeed
        let blueprint = WorldGenerator.blueprint(campaignSeed: seed, world: address.world)
        let slot = blueprint.slots.first { $0.levelNumber == address.level } ?? blueprint.slots[0]
        let generated = LevelGenerator.generate(slot.request)
        lock.lock()
        if let stored = archive.levels.first(where: { $0.address == address })?.level {
            lock.unlock()
            return stored
        }
        archive.levels.append(ArchivedLevel(address: address, level: generated.level))
        persistLocked()
        lock.unlock()
        return generated.level
    }

    func reset() {
        lock.lock()
        archive = CampaignArchive(
            progress: CampaignProgress(campaignSeed: UInt64.random(in: 1...UInt64.max)),
            levels: []
        )
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
