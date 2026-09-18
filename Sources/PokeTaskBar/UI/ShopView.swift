import SwiftUI

/// 상점 — Coins(XP ÷ 1000)로 아이템과 알을 산다. 알은 보관함으로 들어가며 파트너를 놓아주지 않는다.
/// 인라인 확인(버튼 morph) — .sheet/.alert 금지(BagView 주석과 동일: 창이 닫힐 때
/// 고아 시트가 이후 클릭을 먹통내는 결함 회피).
@MainActor
struct ShopView: View {
    let store: CompanionStore
    let nav: PopoverNavigation

    var body: some View {
        let l = store.l
        // 최소 높이 — 컬렉션/가방과 동일. 창이 커지면 스크롤 영역이 나머지를 채운다.
        ContentFittingScrollView {
            VStack(alignment: .leading, spacing: 10) {
                walletHeader(l)
                // shopEntries = 판매 아이템 + 알 3종(보증 없음·고급 이상·희귀 이상)을 가격 오름차순으로
                // 병합한 단일 목록. 알은 항상 포함되고(즉시 액션이라 ItemKind 가 아님), 알 상태에선
                // EggCard 가 구매만 비활성으로 보여준다.
                ForEach(store.shopEntries, id: \.self) { entry in
                    switch entry {
                    case .item(let kind):
                        ShopItemCard(store: store, kind: kind)
                    case .egg(let tier):
                        EggCard(store: store, nav: nav, tier: tier)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func walletHeader(_ l: L) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l.spendableCoins)
                .font(.caption).foregroundStyle(.secondary)
            Text(TokenFormatter.compact(store.availableCoins))
                .font(.system(size: 24, weight: .bold)).monospacedDigit()
            Text(l.shopHint)
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// 상점 아이템 1장 — 아이콘·이름·설명(사탕 XP / 민트 "성격 랜덤 변경")·보유수 + 가격/구매(인라인 확인).
/// kind 별 store.canBuy(kind)/buy(kind) 로 일반화 — 판매 목록은 store.purchasableItems.
@MainActor
struct ShopItemCard: View {
    let store: CompanionStore
    let kind: ItemKind
    @Environment(\.mainWindowChrome) private var mainWindowChrome
    @State private var confirming = false

    private var price: Int { store.price(of: kind) ?? 0 }

    var body: some View {
        if mainWindowChrome { desktopCard } else { compactCard }
    }

    private var desktopCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ItemIconView(kind: kind, size: 48)
                VStack(alignment: .leading, spacing: 7) {
                    Text(store.l.itemName(kind)).font(.system(size: 16, weight: .semibold))
                    if !kind.isPassive { Text(store.l.ownedCount(store.itemCount(kind))).foregroundStyle(.secondary) }
                }
            }
            Text(store.l.itemDescription(kind)).font(.system(size: 13)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            buyControls(store.l)
        }
    }

    private var compactCard: some View {
        let l = store.l
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ItemIconView(kind: kind, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(l.itemName(kind)).font(.callout.weight(.semibold))
                        let owned = store.itemCount(kind)
                        if owned > 0 && !kind.isPassive {
                            Text(l.ownedCount(owned)).font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    Text(l.itemDescription(kind))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            buyControls(l)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func buyControls(_ l: L) -> some View {
        if kind.isPassive && store.itemCount(kind) > 0 {
            // 보유형(이로치 부적 등) — 1회 구매라 소유 후엔 "보유 중" 표시(재구매 버튼 없음).
            HStack(spacing: 5) {
                Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(.green)
                Text(l.ownedAlready).font(.caption2.weight(.semibold)).foregroundStyle(.green)
                Spacer()
            }
        } else if confirming {
            HStack(spacing: 8) {
                Text(l.buyConfirm(l.itemName(kind)))
                    .font(mainWindowChrome ? .system(size: 13) : .caption2).foregroundStyle(.secondary).lineLimit(mainWindowChrome ? 2 : 1)
                Spacer()
                Button(l.buy) { buyNow() }
                    .tahoeButtonStyle(.prominent).controlSize(.small)
                Button(l.cancel) { confirming = false }
                    .tahoeButtonStyle(.accessory).controlSize(.small)
            }
        } else {
            HStack {
                Text(l.requiresCoins(TokenFormatter.compact(price)))
                    .font(mainWindowChrome ? .system(size: 12) : .caption2).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                if store.canBuy(kind) {
                    Button(l.buy) { confirming = true }
                        .tahoeButtonStyle(.regular).controlSize(.small)
                } else {
                    Text(l.notEnoughCoins)
                        .font(mainWindowChrome ? .system(size: 12) : .caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func buyNow() {
        confirming = false
        _ = store.buy(kind)
    }
}

/// 알 카드 — 구매 = Pokémon Storage 에 보관. 지금 키우는 포켓몬은 그대로. `tier` 는 보증 등급 하한.
/// 인라인 2단계 확인: 일반은 1회, 이로치면 한 번 더(사고 폐기 방지). 성공하면 Home 으로 전환해 새 알을 보여준다.
/// 알 상태(활성 없음)에서도 카드는 노출하되 구매 버튼만 비활성 + 사유 한 줄(eggShopLockedHint).
///
/// 등급 알의 시각 구분은 **카드의 등급 배지**로만 한다 — 알 스프라이트는 한 장뿐이고, 메뉴바·플로팅 펫은
/// 기존 알 그대로 둔다(새 에셋 없이 구분이 서는 최소 범위).
@MainActor
struct EggCard: View {
    let store: CompanionStore
    let nav: PopoverNavigation
    let tier: Rarity?
    @Environment(\.mainWindowChrome) private var mainWindowChrome
    @State private var stage: Stage = .idle
    private enum Stage { case idle, confirm, shinyConfirm }

    private var price: Int { store.price(of: .egg(tier)) }

    var body: some View {
        if mainWindowChrome { desktopCard } else { compactCard }
    }

    private var desktopCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                SpriteView(speciesID: nil, size: 48, cropToContent: true)
                VStack(alignment: .leading, spacing: 7) {
                    Text(store.l.eggName(tier)).font(.system(size: 16, weight: .semibold))
                    if let tier { Text(store.l.rarityLabel(tier)).font(.system(size: 12))
                        .foregroundStyle(rarityColor(tier)) }
                }
            }
            Text(store.l.eggDescription(tier)).font(.system(size: 13)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            controls(store.l)
        }
    }

    private var compactCard: some View {
        let l = store.l
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                // 크롭+정사각 보정한 알. 레이아웃은 30(다른 아이템 아이콘과 정렬 일치)으로 두되 알 자체는 26으로
                // 살짝 작게 — 프레임에 여백이 생겨 꽉 찬 "뚱뚱" 느낌이 줄고 크기도 약간 작아진다.
                SpriteView(speciesID: nil, size: 26)
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(l.eggName(tier)).font(.callout.weight(.semibold))
                        if let tier {
                            // 도감 칩과 같은 라벨·색 — 상점의 등급 표기가 도감과 한 말로 맞물리게.
                            Text(l.rarityLabel(tier).uppercased()).font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(rarityColor(tier)).foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    Text(l.eggDescription(tier))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            controls(l)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func controls(_ l: L) -> some View {
        switch stage {
        case .idle:
            HStack {
                Text(l.requiresCoins(TokenFormatter.compact(price)))
                    .font(mainWindowChrome ? .system(size: 12) : .caption2).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                if store.canBuyEgg(tier) {
                    Button(l.buy) { stage = .confirm }
                        .tahoeButtonStyle(.regular).controlSize(.small)
                } else {
                    Text(l.notEnoughCoins).font(mainWindowChrome ? .system(size: 12) : .caption2).foregroundStyle(.secondary)
                }
            }
        case .confirm:
            HStack(spacing: 8) {
                Text(l.eggStorageConfirm(l.eggName(tier)))
                    .font(mainWindowChrome ? .system(size: 13) : .caption2).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
                Button(l.buy) { commit() }
                    .tahoeButtonStyle(.prominent).controlSize(.small)
                Button(l.cancel) { stage = .idle }
                    .tahoeButtonStyle(.accessory).controlSize(.small)
            }
        case .shinyConfirm:
            EmptyView()
        }
    }

    /// Egg banks in Pokémon Storage. Current partner stays in training.
    private func commit() {
        stage = .idle
        if store.buyEgg(tier) {
            nav.collectionSegment = .storage
            nav.tab = .collection
        }
    }
}
