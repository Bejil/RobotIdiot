import Foundation
import RobotIdiotCore

struct ArchivedLevel: Codable {
    var address: LevelAddress
    var level: Level
}

struct StoredProgram: Codable {
    var address: LevelAddress
    var program: Program
}

struct CampaignArchive: Codable {
    var progress: CampaignProgress
    var levels: [ArchivedLevel]
    var programs: [StoredProgram]

    init(progress: CampaignProgress, levels: [ArchivedLevel], programs: [StoredProgram]) {
        self.progress = progress
        self.levels = levels
        self.programs = programs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        progress = try container.decode(CampaignProgress.self, forKey: .progress)
        levels = try container.decodeIfPresent([ArchivedLevel].self, forKey: .levels) ?? []
        programs = try container.decodeIfPresent([StoredProgram].self, forKey: .programs) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(progress, forKey: .progress)
        try container.encode(levels, forKey: .levels)
        try container.encode(programs, forKey: .programs)
    }

    private enum CodingKeys: String, CodingKey {
        case progress
        case levels
        case programs
    }
}

final class CampaignStore {
    static let shared = CampaignStore()

    private let lock = NSLock()
    private var archive: CampaignArchive
    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RobotIdiot", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("campaign.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(CampaignArchive.self, from: data),
           decoded.progress.formulaVersion == CatalogCampaign.formulaVersion {
            archive = decoded
            // Les programmes des niveaux déjà réussis ne sont plus conservés.
            purgeCompletedProgramsLocked()
            persistLocked()
        } else {
            // Nouvelle formule / pack : progression effacée → les intros de commandes recommencent.
            archive = CampaignStore.freshArchive()
            persistLocked()
            PlaySettings.resetIntroducedCommands()
        }
    }

    private static func freshArchive() -> CampaignArchive {
        CampaignArchive(
            progress: CampaignProgress(campaignSeed: 1, formulaVersion: CatalogCampaign.formulaVersion),
            levels: [],
            programs: []
        )
    }

    func progress() -> CampaignProgress {
        lock.lock()
        defer { lock.unlock() }
        return archive.progress
    }

    func record(_ score: LevelScore, at address: LevelAddress) {
        lock.lock()
        CampaignRules.record(score, at: address, in: &archive.progress)
        // Une fois le niveau réussi, on oublie le programme (rejouer part d'une feuille blanche).
        archive.programs.removeAll { $0.address == address }
        persistLocked()
        lock.unlock()
    }

    func level(at address: LevelAddress) -> Level? {
        CatalogCampaign.level(at: address)
    }

    func program(at address: LevelAddress) -> Program? {
        lock.lock()
        defer { lock.unlock() }
        // Pas de brouillon pour un niveau déjà validé.
        guard archive.progress.score(at: address) == nil else { return nil }
        return archive.programs.first { $0.address == address }?.program
    }

    func save(_ program: Program, at address: LevelAddress) {
        lock.lock()
        // Ne mémorise le programme que tant que le niveau n'est pas réussi.
        guard archive.progress.score(at: address) == nil else {
            archive.programs.removeAll { $0.address == address }
            persistLocked()
            lock.unlock()
            return
        }
        if let index = archive.programs.firstIndex(where: { $0.address == address }) {
            archive.programs[index].program = program
        } else {
            archive.programs.append(StoredProgram(address: address, program: program))
        }
        persistLocked()
        lock.unlock()
    }

    func materialize(_ address: LevelAddress, completion: @escaping (Level) -> Void) {
        guard let level = CatalogCampaign.level(at: address) else { return }
        DispatchQueue.main.async {
            completion(level)
        }
    }

    func warm(_ address: LevelAddress) {
    }

    func reset() {
        lock.lock()
        archive = CampaignStore.freshArchive()
        persistLocked()
        lock.unlock()
        PlaySettings.resetIntroducedCommands()
        // Les écrous déjà gagnés restent : seule la progression de campagne est effacée.
        // (Une mise à jour de formule recrée le store ; le portefeuille est indépendant.)
    }

    private func purgeCompletedProgramsLocked() {
        // Copie locale : `removeAll` mute `archive` et ne peut pas lire `archive.progress` en même temps.
        let progress = archive.progress
        archive.programs.removeAll { progress.score(at: $0.address) != nil }
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
