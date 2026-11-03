import Foundation

/// Cible d'étoiles d'un parcours (avec ou sans bonus).
public struct CatalogStarRoute: Codable, Equatable, Sendable {
    public var optimal: Int
    public var threeStarsMax: Int
    public var optimality: String?

    public init(optimal: Int, threeStarsMax: Int, optimality: String? = nil) {
        self.optimal = optimal
        self.threeStarsMax = threeStarsMax
        self.optimality = optimality
    }
}

public struct CatalogStarTargets: Codable, Equatable, Sendable {
    public var metric: String
    public var selectionRule: String?
    public var withoutBonus: CatalogStarRoute
    public var withBonus: CatalogStarRoute?

    public init(
        metric: String = "executedPrimitiveActions",
        selectionRule: String? = nil,
        withoutBonus: CatalogStarRoute,
        withBonus: CatalogStarRoute? = nil
    ) {
        self.metric = metric
        self.selectionRule = selectionRule
        self.withoutBonus = withoutBonus
        self.withBonus = withBonus
    }
}

public struct CatalogCollectible: Codable, Equatable, Sendable {
    public var id: String
    public var type: String
    public var x: Int
    public var y: Int
    public var amount: Int
    public var optional: Bool
    public var pickup: String
    public var layer: String?
    public var grantCondition: String?
    public var repeatable: Bool

    private enum CodingKeys: String, CodingKey {
        case id, type, x, y, amount, optional, pickup, layer, grantCondition, repeatable
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        x = try container.decode(Int.self, forKey: .x)
        y = try container.decode(Int.self, forKey: .y)
        amount = try container.decodeIfPresent(Int.self, forKey: .amount) ?? 2
        optional = try container.decodeIfPresent(Bool.self, forKey: .optional) ?? true
        pickup = try container.decodeIfPresent(String.self, forKey: .pickup) ?? "auto_on_enter"
        layer = try container.decodeIfPresent(String.self, forKey: .layer)
        grantCondition = try container.decodeIfPresent(String.self, forKey: .grantCondition)
        repeatable = try container.decodeIfPresent(Bool.self, forKey: .repeatable) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(amount, forKey: .amount)
        try container.encode(optional, forKey: .optional)
        try container.encode(pickup, forKey: .pickup)
        try container.encodeIfPresent(layer, forKey: .layer)
        try container.encodeIfPresent(grantCondition, forKey: .grantCondition)
        try container.encode(repeatable, forKey: .repeatable)
    }
}

public struct CatalogRewards: Codable, Equatable, Sendable {
    public var currency: String
    public var completionOnly: Bool
    public var repeatable: Bool
    public var collectibles: [CatalogCollectible]

    private enum CodingKeys: String, CodingKey {
        case currency, completionOnly, repeatable, collectibles
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "bolt"
        completionOnly = try container.decodeIfPresent(Bool.self, forKey: .completionOnly) ?? true
        repeatable = try container.decodeIfPresent(Bool.self, forKey: .repeatable) ?? false
        collectibles = try container.decodeIfPresent([CatalogCollectible].self, forKey: .collectibles) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currency, forKey: .currency)
        try container.encode(completionOnly, forKey: .completionOnly)
        try container.encode(repeatable, forKey: .repeatable)
        try container.encode(collectibles, forKey: .collectibles)
    }
}

/// Collectible de plateau (overlay), distinct des objets ramassables (clés).
public struct LevelCollectible: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: String
    public var position: GridCoordinate
    public var amount: Int

    public init(id: String, kind: String, position: GridCoordinate, amount: Int) {
        self.id = id
        self.kind = kind
        self.position = position
        self.amount = amount
    }

    public var isBolt: Bool { kind == "BoardBolt" }
}

/// Coûts configurables de l'économie d'écrous.
public enum RewardEconomy: Sendable {
    public static let hintCost = 3
    public static let adFreeRetryCost = 1
    public static let fullSolutionCost = 6
    public static let defaultAwardAmount = 2
}
