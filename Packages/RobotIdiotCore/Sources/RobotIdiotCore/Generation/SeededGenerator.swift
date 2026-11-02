import Foundation

/// Générateur déterministe. La même graine produit la même suite sur chaque appareil.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58476D1CE4E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D049BB133111EB
        return mixed ^ (mixed >> 31)
    }

    public mutating func int(_ range: Range<Int>) -> Int {
        precondition(!range.isEmpty)
        let span = UInt64(range.count)
        return range.lowerBound + Int(next() % span)
    }

    public mutating func bool() -> Bool {
        next() & 1 == 0
    }
}
