import XCTest
import AppKit
import SwiftUI
@testable import PokeTaskBar

// MARK: 상점 (재화 = usedSinceInstall − spentTokens, 이상한 사탕 구매)

/// 라인 로딩이 필요 없는 상점 테스트용 provider(항상 throw — 지갑/구매는 라인과 무관).
private struct ShopNoProvider: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine { throw URLError(.notConnectedToInternet) }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}

@MainActor
final class ShopTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// usedSinceInstall/spentTokens 를 직접 지정한 상태 파일을 만들어 로드 — 지갑 잔액을 결정적으로
    /// 세팅(update() 의 delta 적립 경로를 우회). testCannotUseWhileLineUnloaded 와 동일한 JSON 시드 패턴.
    private func store(used: Int, spent: Int = 0, rareCandy: Int = 0,
                       file: String = #filePath) -> CompanionStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shop-\(UUID().uuidString).json")
        let inv = rareCandy > 0 ? ",\"inventory\":{\"rareCandy\":\(rareCandy)}" : ""
        let json = "{\"installBaselineSet\":true,\"usedSinceInstall\":\(used),\"spentTokens\":\(spent),"
            + "\"lastDate\":\"d\",\"dex\":[],\"collectedFinals\":[]\(inv)}"
        try? json.data(using: .utf8)!.write(to: url)
        let suite = "ShopTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: ShopNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 1), defaults: defaults)
    }

    // MARK: 잔액 계산

    func testAvailableEqualsCoinsFromXPWhenNothingSpent() {
        XCTAssertEqual(store(used: 1_000_000_000).availableCoins, 1_000_000)
        XCTAssertEqual(store(used: 1_000_000_000).availableTokens, 1_000_000)
    }

    func testAvailableSubtractsSpentCoins() {
        XCTAssertEqual(store(used: 1_000_000_000, spent: 300_000).availableCoins, 700_000)
    }

    /// spent > coins(비정상 상태 파일)이어도 음수로 새지 않는다(max 가드).
    func testAvailableNeverNegative() {
        XCTAssertEqual(store(used: 100_000, spent: 500).availableCoins, 0)
    }

    /// 하위호환: spentTokens 키 없는 구버전 저장 → 0 으로 로드(잔액 = used).
    func testDecodesWithoutSpentTokens() throws {
        let json = #"{"installBaselineSet":true,"usedSinceInstall":900,"lastDate":"d","dex":[]}"#
        let s = try JSONDecoder().decode(CompanionState.self, from: Data(json.utf8))
        XCTAssertEqual(s.spentTokens, 0)
        XCTAssertEqual(s.usedSinceInstall, 900)
    }

    func testSpentTokensRoundTrip() throws {
        var st = CompanionState()
        st.usedSinceInstall = 1000
        st.spentTokens = 400
        let round = try JSONDecoder().decode(CompanionState.self, from: JSONEncoder().encode(st))
        XCTAssertEqual(round.spentTokens, 400)
    }

    // MARK: 구매 가능 판정 (경계)

    func testCanBuyAtExactPrice() {
        XCTAssertTrue(store(used: EconomyScale.xpForCoins(RareCandy.price)).canBuyRareCandy)
    }

    func testCannotBuyOneBelowPrice() {
        XCTAssertFalse(store(used: EconomyScale.xpForCoins(RareCandy.price) - 1).canBuyRareCandy)
    }

    // MARK: 구매 (차감 + 적립 + 영속)

    func testBuyDebitsWalletAndCreditsInventory() {
        let s = store(used: 1_000_000_000)
        XCTAssertTrue(s.buyRareCandy())
        XCTAssertEqual(s.rareCandyCount, 1)
        XCTAssertEqual(s.state.spentTokens, RareCandy.price)
        XCTAssertEqual(s.availableCoins, 1_000_000 - RareCandy.price)
        XCTAssertEqual(s.state.usedSinceInstall, 1_000_000_000, "성장 미터(usedSinceInstall)는 불변")
    }

    /// 잔액 부족이면 no-op — 인벤토리·지출 원장 불변, false 반환.
    func testBuyInsufficientIsNoOp() {
        let s = store(used: EconomyScale.xpForCoins(RareCandy.price) - 1)
        XCTAssertFalse(s.buyRareCandy())
        XCTAssertEqual(s.rareCandyCount, 0)
        XCTAssertEqual(s.state.spentTokens, 0)
    }

    /// 여러 번 구매하면 잔액이 바닥날 때까지만 성공(가드가 매번 재평가).
    func testMultipleBuysUntilBroke() {
        let leftover = RareCandy.price / 2
        let s = store(used: EconomyScale.xpForCoins(2 * RareCandy.price + leftover))
        XCTAssertTrue(s.buyRareCandy())
        XCTAssertTrue(s.buyRareCandy())
        XCTAssertFalse(s.buyRareCandy())
        XCTAssertEqual(s.rareCandyCount, 2)
        XCTAssertEqual(s.state.spentTokens, 2 * RareCandy.price)
        XCTAssertEqual(s.availableCoins, leftover)
    }

    /// 구매는 이미 가진 사탕에 합산된다(무료 지급분과 같은 인벤토리).
    func testBuyAddsToExistingStock() {
        let s = store(used: 1_000_000_000, rareCandy: 3)
        XCTAssertTrue(s.buyRareCandy())
        XCTAssertEqual(s.rareCandyCount, 4)
        XCTAssertEqual(s.ownedItems.first?.kind, .rareCandy)
        XCTAssertEqual(s.ownedItems.first?.count, 4)
    }

    func testBulkPurchaseUsesScaledPriceAndCreditsEntireQuantity() {
        for kind in [ItemKind.rareCandy, .mint] {
            let s = store(used: EconomyScale.xpForCoins(3 * kind.shopPrice!), rareCandy: 2)
            s.setShopDifficulty(0.5)
            let price = s.price(of: kind)!
            let owned = s.itemCount(kind)
            XCTAssertEqual(s.maxBuyCount(kind), 6)
            XCTAssertTrue(s.canBuy(kind, count: 3))
            XCTAssertTrue(s.buy(kind, count: 3))
            XCTAssertEqual(s.itemCount(kind), owned + 3)
            XCTAssertEqual(s.state.spentTokens, 3 * price)
            XCTAssertEqual(s.maxBuyCount(kind), 3)
        }
    }

    func testBulkPurchaseRejectsInvalidAndUnaffordableQuantitiesWithoutPartialPurchase() {
        let s = store(used: EconomyScale.xpForCoins(2 * RareCandy.price), rareCandy: 2)
        XCTAssertEqual(s.maxBuyCount(.rareCandy), 2)
        for count in [-1, 0, 3, Int.max] {
            XCTAssertFalse(s.canBuy(.rareCandy, count: count))
            XCTAssertFalse(s.buy(.rareCandy, count: count))
            XCTAssertEqual(s.rareCandyCount, 2)
            XCTAssertEqual(s.state.spentTokens, 0)
        }
        XCTAssertTrue(s.buy(.rareCandy, count: 2))
        XCTAssertEqual(s.availableCoins, 0)
        XCTAssertEqual(s.maxBuyCount(.rareCandy), 0)
        XCTAssertFalse(s.buy(.rareCandy))
    }

    func testPassiveQuantityIsLimitedToOne() {
        let s = store(used: EconomyScale.xpForCoins(3 * ShinyCharm.price))
        XCTAssertEqual(s.maxBuyCount(.shinyCharm), 1)
        XCTAssertFalse(s.buy(.shinyCharm, count: 2))
        XCTAssertEqual(s.state.spentTokens, 0)
        XCTAssertTrue(s.buy(.shinyCharm))
        XCTAssertEqual(s.maxBuyCount(.shinyCharm), 0)
        XCTAssertFalse(s.buy(.shinyCharm))
        XCTAssertEqual(s.itemCount(.shinyCharm), 1)
    }

    func testShopScrollsWithoutShowingOrFlashingScrollbars() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let root = ShopView(store: store(used: 1_000_000_000), nav: PopoverNavigation())
            .frame(width: 360, height: 180)
        let host = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 180),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil }
        try await Task.sleep(for: .milliseconds(150))
        host.layoutSubtreeIfNeeded()
        func findScrollView(in view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView { return scroll }
            return view.subviews.lazy.compactMap { findScrollView(in: $0) }.first
        }
        let scroll = try XCTUnwrap(findScrollView(in: host))
        XCTAssertFalse(scroll.hasVerticalScroller)
        XCTAssertFalse(scroll.hasHorizontalScroller)
        let before = scroll.contentView.bounds.origin.y
        try XCTUnwrap(scroll.documentView).scroll(NSPoint(x: 0, y: before + 120))
        scroll.flashScrollers()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertGreaterThan(scroll.contentView.bounds.origin.y, before, "Content must remain scrollable")
        XCTAssertFalse(scroll.hasVerticalScroller, "Scrolling must not reveal a scrollbar")
        XCTAssertFalse(scroll.hasHorizontalScroller)
    }

    func testNativeBuyAdjustQuantityCancelAndPurchaseInBothLayouts() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        for desktop in [false, true] {
            let s = store(used: EconomyScale.xpForCoins(3 * RareCandy.price))
            let root = ShopItemCard(store: s, kind: .rareCandy)
                .environment(\.mainWindowChrome, desktop)
                .environment(\.colorScheme, .light)
                .transaction { $0.disablesAnimations = true }
                .frame(width: desktop ? 280 : 360)
                .background(Color.white)
            let host = NSHostingView(rootView: root)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: desktop ? 280 : 360, height: 320),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .aqua)
            window.contentView = host
            window.orderFrontRegardless()
            defer { window.orderOut(nil); window.contentView = nil }
            func settle() async throws {
                try await Task.sleep(for: .milliseconds(100))
                window.setContentSize(host.fittingSize)
                host.layoutSubtreeIfNeeded()
            }
            func click(x: CGFloat, bottom: CGFloat) async throws {
                let point = host.convert(NSPoint(x: x, y: host.isFlipped ? host.bounds.height - bottom : bottom), to: nil)
                for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                    window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                        modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
                }
                try await settle()
            }
            func capture(_ stage: String) throws {
                guard let directory = ProcessInfo.processInfo.environment["PTB_SHOP_PREVIEW_DIR"] else { return }
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to:
                    URL(fileURLWithPath: directory).appendingPathComponent("shop-\(desktop)-\(stage).png"))
            }
            func findStepper(in view: NSView) -> NSStepper? {
                if let stepper = view as? NSStepper { return stepper }
                return view.subviews.lazy.compactMap { findStepper(in: $0) }.first
            }
            func adjust(_ increase: Bool) async throws {
                let stepper = try XCTUnwrap(findStepper(in: host))
                let y = stepper.bounds.height * ((increase != stepper.isFlipped) ? 0.75 : 0.25)
                let point = stepper.convert(NSPoint(x: stepper.bounds.midX, y: y), to: host)
                try await click(x: point.x, bottom: host.isFlipped ? host.bounds.height - point.y : point.y)
            }
            try await settle()
            try capture("before")
            let trailing = host.bounds.width - (desktop ? 0 : 10)
            try await click(x: trailing - 20, bottom: desktop ? 12 : 22)
            try capture("quantity")
            XCTAssertEqual(s.rareCandyCount, 0, "Opening Buy must not spend coins")
            try await click(x: trailing - 25, bottom: desktop ? 12 : 22)
            XCTAssertEqual(s.state.spentTokens, 0)
            try await click(x: trailing - 20, bottom: desktop ? 12 : 22)
            try await adjust(true)
            try await adjust(false)
            try capture("lowered")
            try await click(x: trailing - 95, bottom: desktop ? 12 : 22)
            XCTAssertEqual(s.rareCandyCount, 1, "Decreasing the quantity must buy only one")
            XCTAssertEqual(s.state.spentTokens, RareCandy.price)
            try await click(x: trailing - 20, bottom: desktop ? 12 : 22)
            try await adjust(true)
            try await adjust(true)
            try capture("selected")
            try await click(x: trailing - 95, bottom: desktop ? 12 : 22)
            XCTAssertEqual(s.rareCandyCount, 3, "Increasing must stop at the affordable quantity")
            XCTAssertEqual(s.state.spentTokens, 3 * RareCandy.price)
            XCTAssertEqual(s.availableCoins, 0)
            try capture("after")
        }
    }

    /// [영속] 재시작(같은 파일 재로드) 후 지출·재고가 유지된다.
    func testBuyPersistsAcrossRestart() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shop-persist-\(UUID().uuidString).json")
        let json = "{\"installBaselineSet\":true,\"usedSinceInstall\":1000000000,\"spentTokens\":0,"
            + "\"lastDate\":\"d\",\"dex\":[],\"collectedFinals\":[]}"
        try? json.data(using: .utf8)!.write(to: url)
        let s1 = CompanionStore(provider: ShopNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 1))
        XCTAssertTrue(s1.buy(.rareCandy, count: 3))

        let s2 = CompanionStore(provider: ShopNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 1))
        XCTAssertEqual(s2.rareCandyCount, 3, "재고 영속")
        XCTAssertEqual(s2.state.spentTokens, 3 * RareCandy.price, "지출 영속")
        XCTAssertEqual(s2.availableCoins, 1_000_000 - 3 * RareCandy.price)
    }

    // MARK: 정렬 (가격 저렴한 순 + 구매 완료 보유형 맨 아래)

    /// 상점 목록은 가격 오름차순(민트 < 사탕 < 이로치 부적).
    func testItemsSortedByPriceAscending() {
        let items = store(used: 0).purchasableItems
        XCTAssertEqual(items, [.mint, .rareCandy, .shinyCharm])
        let prices = items.compactMap(\.shopPrice)
        XCTAssertEqual(prices, prices.sorted(), "shopPrice 오름차순 — 가격 상수가 바뀌어도 정렬 불변식 유지")
    }

    /// 구매 완료한 보유형(이로치 부적)은 맨 아래로. 재구매 불가라 상단에 둘 이유 없음.
    /// (현재 부적이 최고가라 가격순 결과와 일치하지만, 향후 저가 보유형이 생겨도 규칙이 유지되도록 게이트.)
    func testOwnedPassiveSinksToBottom() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shop-sort-\(UUID().uuidString).json")
        let json = "{\"installBaselineSet\":true,\"usedSinceInstall\":0,\"spentTokens\":0,"
            + "\"lastDate\":\"d\",\"dex\":[],\"collectedFinals\":[],\"inventory\":{\"shinyCharm\":1}}"
        try? json.data(using: .utf8)!.write(to: url)
        let s = CompanionStore(provider: ShopNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 1))
        XCTAssertTrue(s.itemCount(.shinyCharm) > 0)
        XCTAssertEqual(s.purchasableItems.last, .shinyCharm, "구매 완료 보유형은 최하단")
    }

    // MARK: shopEntries (판매 아이템 + 알 3종을 하나의 가격 오름차순 목록으로 병합)

    /// 활성 포켓몬이 있으면 알 3종이 각자의 가격 위치에 끼워져 전체가 가격 오름차순.
    /// (회귀: 알이 ForEach 밖에서 무조건 맨 아래로 append 돼 3B 부적보다 아래에 놓이던 표시.)
    /// 등급 알을 인접 그룹으로 묶지 **않는** 것이 의도다 — 그러면 4B 희귀 알이 3B 부적 위로 올라가
    /// 위 회귀를 부분적으로 되살린다. 티어 관계는 카드의 등급 배지로 읽힌다.
    func testShopEntriesInterleavesFreshEggByPrice() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shop-entries-\(UUID().uuidString).json")
        let mon = "{\"baseID\":10,\"pathIDs\":[10],\"stageIndex\":0,\"usedAtStage\":200000000,"
            + "\"rarity\":\"common\",\"totalForms\":3,\"isShiny\":false}"
        let json = "{\"installBaselineSet\":true,\"usedSinceInstall\":5000000000,\"spentTokens\":0,"
            + "\"lastDate\":\"d\",\"active\":\(mon),\"dex\":[],\"collectedFinals\":[]}"
        try? json.data(using: .utf8)!.write(to: url)
        let s = CompanionStore(provider: ShopNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 1))
        XCTAssertTrue(s.hasActive)
        XCTAssertEqual(s.shopEntries,
                       [.item(.mint),
                        .item(.rareCandy),
                        .egg(nil),
                        .egg(.uncommon),
                        .item(.shinyCharm),
                        .egg(.rare)])
        let prices = s.shopEntries.map(\.price)
        XCTAssertEqual(prices, prices.sorted(), "가격 상수가 바뀌어도 오름차순 불변식 유지")
    }

    /// Eggs stay listed without an active partner, and buying banks them in storage.
    func testShopEntriesKeepsEggsBuyableWhenNoActive() {
        let s = store(used: 5_000_000_000)
        XCTAssertFalse(s.hasActive)
        XCTAssertEqual(s.shopEntries,
                       [.item(.mint),
                        .item(.rareCandy),
                        .egg(nil),
                        .egg(.uncommon),
                        .item(.shinyCharm),
                        .egg(.rare)])
        let prices = s.shopEntries.map(\.price)
        XCTAssertEqual(prices, prices.sorted(), "가격 상수가 바뀌어도 오름차순 불변식 유지")
        XCTAssertEqual(prices, [Mint.price, RareCandy.price, FreshEgg.price,
                                FreshEgg.price(guaranteeing: .uncommon), ShinyCharm.price,
                                FreshEgg.price(guaranteeing: .rare)])
        for tier in FreshEgg.shopTiers {
            XCTAssertTrue(s.shopEntries.contains(.egg(tier)))
            XCTAssertTrue(s.canBuyEgg(tier), "보관함 알은 활성 파트너 없이 살 수 있다")
        }
        XCTAssertTrue(s.buyEgg(nil))
        XCTAssertEqual(s.storedCompanions.count, 1)
        XCTAssertTrue(s.storedCompanions[0].isEgg)
        XCTAssertFalse(s.hasActive, "구매가 파트너를 놓아주지 않는다")
        XCTAssertEqual(s.availableCoins, 5_000_000 - FreshEgg.price)
    }
}
