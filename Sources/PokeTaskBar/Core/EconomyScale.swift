import Foundation

/// Fork-only economy knob. Official PokeTokenBar hatch/shop integers stay in call sites.
///
/// PokeTaskBar prices: take the 1% fork scale, then convert XP → Coins (`÷ 1000`).
enum EconomyScale {
    /// 0.01 = 1% of official hatch / evolve / shop token costs.
    static let factor: Double = 0.01
    /// Shop currency. `Coins = floor(XP / xpPerCoin)`.
    static let xpPerCoin = 1000

    static func tokens(_ upstream: Int) -> Int {
        Int((Double(upstream) * factor).rounded())
    }

    /// Seed shop prices: 1% of upstream, then ÷ 1000 into Coins.
    static func coins(_ upstream: Int) -> Int {
        tokens(upstream) / xpPerCoin
    }

    static func coinsFromXP(_ xp: Int) -> Int {
        max(0, xp / xpPerCoin)
    }

    /// XP that yields exactly `coins` spendable Coins when nothing has been spent.
    static func xpForCoins(_ coins: Int) -> Int {
        max(0, coins) * xpPerCoin
    }
}
