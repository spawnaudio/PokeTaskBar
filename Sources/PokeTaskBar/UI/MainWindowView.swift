import AppKit
import SwiftUI

@MainActor
struct MainWindowView: View {
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session
    @Environment(MainWindowNavigation.self) private var nav
    @Environment(\.colorScheme) private var scheme
    @FocusState private var searchFocused: Bool
    private var l: L { companion.l }
    private var theme: MainWindowTheme { MainWindowTheme(scheme: scheme) }

    var body: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width - 24)
            let layout = store.todayDeskLayout.resolved(containerWidth: width)
            VStack(spacing: 0) {
                toolbar
                HStack(alignment: .top, spacing: 0) {
                    if !layout.leftCollapsed {
                        navigation.frame(width: layout.leftWidth)
                    }
                    MainWindowResizeBoundary(width: layout.leftWidth, reversed: false,
                        collapsed: layout.leftCollapsed) { value in
                            store.todayDeskLayout = store.todayDeskLayout.settingLeftWidth(value, containerWidth: width)
                        }
                    canvas
                        .environment(\.popoverContentWidth, max(280, layout.centerWidth - 48))
                    MainWindowResizeBoundary(width: layout.rightWidth, reversed: true,
                        collapsed: layout.rightCollapsed) { value in
                            store.todayDeskLayout = store.todayDeskLayout.settingRightWidth(value, containerWidth: width)
                        }
                    if !layout.rightCollapsed {
                        MainWindowExtrasView().frame(width: layout.rightWidth)
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 12)
            }
        }
        .background(theme.shell).foregroundStyle(theme.text).tint(.blue)
        .font(.system(size: 14))
        .environment(nav.content)
        .environment(\.mainWindowChrome, true)
        .environment(\.menuBarChrome, true)
        .environment(\.menuBarContentFitting, false)
        .onChange(of: nav.content.showSettings) { _, value in
            if value { nav.select(.settings) }
        }
        .onChange(of: nav.content.tab) { _, value in
            if value == .focus && nav.page != .today { nav.select(.focus) }
            if value == .collection { nav.select(.collection) }
        }
        .task(id: store.linearIntegrationEnabled && store.linearAPIKeyConfigured) {
            if store.linearIntegrationEnabled && store.linearAPIKeyConfigured {
                _ = await store.refreshLinearIssues()
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            chromeButton("sidebar.left", title: store.todayDeskLayout.leftCollapsed ? l.expandLeftSidebar : l.collapseLeftSidebar) {
                store.todayDeskLayout = store.todayDeskLayout.togglingLeft()
            }
            chromeButton("chevron.left", title: l.back, enabled: nav.canGoBack) { nav.back() }
            chromeButton("chevron.right", title: "Forward", enabled: nav.canGoForward) { nav.forward() }
            Label(nav.page.title(l), systemImage: nav.page.symbol)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .frame(minWidth: 160, alignment: .leading)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 7))
            Spacer()
            chromeButton("sidebar.right", title: store.todayDeskLayout.rightCollapsed ? l.expandRightSidebar : l.collapseRightSidebar) {
                store.todayDeskLayout = store.todayDeskLayout.togglingRight()
            }
        }
        .padding(.leading, 90).padding(.trailing, 22).frame(height: 48)
    }

    private func chromeButton(_ icon: String, title: String, enabled: Bool = true,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 26, height: 28).contentShape(Rectangle())
        }.buttonStyle(.plain).help(title).accessibilityLabel(title).disabled(!enabled)
    }

    private var navigation: some View {
        @Bindable var nav = nav
        return VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(nsImage: MenuBarIcon.pokeBall).resizable().frame(width: 23, height: 23)
                    Text("PokeTaskBar").font(.system(size: 17, weight: .semibold))
                }
                Text("Your workspace").foregroundStyle(theme.secondary).font(.system(size: 13))
            }.padding(.horizontal, 10).padding(.top, 12)
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                TextField("Search pages…", text: $nav.search)
                    .textFieldStyle(.plain).focused($searchFocused)
                    .onSubmit {
                        if let first = MainWindowPage.allCases.first(where: {
                            $0.title(l).localizedCaseInsensitiveContains(nav.search)
                        }) { nav.select(first); nav.search = "" }
                    }
            }
            .font(.system(size: 13)).padding(9)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 7))
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(MainWindowPage.allCases.filter { $0 != .settings &&
                        (nav.search.isEmpty || $0.title(l).localizedCaseInsensitiveContains(nav.search)) }) { page in
                        navigationRow(page)
                    }
                }
            }.scrollIndicators(.hidden)
            navigationRow(.settings)
        }
        .padding(.horizontal, 8).padding(.bottom, 12)
        .background {
            Button("") { searchFocused = true }.keyboardShortcut("k", modifiers: .command).hidden()
        }
    }

    private func navigationRow(_ page: MainWindowPage) -> some View {
        Button { nav.search = ""; nav.select(page) } label: {
            HStack(spacing: 12) {
                Image(systemName: page.symbol).font(.system(size: 17)).frame(width: 23)
                Text(page.title(l)).font(.system(size: 14))
                Spacer(minLength: 0)
            }.padding(.horizontal, 10).padding(.vertical, 10)
                .background(nav.page == page ? theme.selected : .clear,
                            in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityIdentifier("main-nav-\(page.rawValue)")
            .accessibilityAddTraits(nav.page == page ? .isSelected : [])
    }

    private var canvas: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text(nav.page.title(l)).font(.system(size: 30, weight: .semibold))
                if nav.page == .today {
                    Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide).year())
                        .foregroundStyle(theme.secondary)
                }
            }
            pageContent.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipped()
    }

    @ViewBuilder private var pageContent: some View {
        switch nav.page {
        case .today: MainWindowTodayView()
        case .focus: MainWindowFocusView()
        case .issues, .projects, .initiatives: MainWindowWorkspacesView(page: nav.page)
        case .collection: MainWindowCollectionView()
        case .usage: UsageTabView()
        case .settings:
            SettingsView(onClose: { nav.back() }, onChooseRepresentative: {
                nav.content.openRepresentativeDex(); nav.select(.collection)
            }, startExpanded: nav.content.expandAdvancedOnOpen)
        }
    }
}

/// The hit target is always available; its guide is visible only near the boundary.
@MainActor
private struct MainWindowResizeBoundary: View {
    let width: CGFloat
    let reversed: Bool
    let collapsed: Bool
    let onResize: (CGFloat) -> Void
    @State private var hovering = false
    @State private var origin: CGFloat?
    var body: some View {
        Rectangle().fill(.clear).frame(width: TodayDeskMetrics.splitterWidth)
            .frame(maxHeight: .infinity).contentShape(Rectangle())
            .overlay { Rectangle().fill(Color.primary.opacity(hovering || origin != nil ? 0.14 : 0))
                .frame(width: 1).padding(.vertical, 16) }
            .onHover { value in
                guard !collapsed else { return }
                if value != hovering {
                    hovering = value
                    if value { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                }
            }
            .onDisappear { if hovering { NSCursor.pop(); hovering = false } }
            .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                guard !collapsed else { return }
                if origin == nil { origin = width }
                onResize((origin ?? width) + value.translation.width * (reversed ? -1 : 1))
            }.onEnded { _ in origin = nil })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(reversed ? "Extras width" : "Navigation width")
            .accessibilityValue("\(Int(width)) points")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onResize(width + 16)
                case .decrement: onResize(width - 16)
                @unknown default: break
                }
            }
            .accessibilityHidden(collapsed)
    }
}

@MainActor
struct MainWindowTodayView: View {
    @Environment(UsageStore.self) private var usage
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session
    @Environment(MainWindowNavigation.self) private var nav
    private var l: L { companion.l }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text(greeting).font(.system(size: 27, weight: .semibold))
                        Text("One thing at a time.").foregroundStyle(.secondary)
                    }.padding(.top, 8)
                    MainWindowCompanionHero(size: min(240, max(140, geometry.size.height * 0.34)))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                             count: geometry.size.width >= 500 ? 3 : 1), spacing: 12) {
                        shortcut(.issues, detail: "View and manage")
                        shortcut(.projects, detail: "Your workspaces")
                        shortcut(.collection, detail: "Your Pokémon")
                    }
                    nextFocus
                }.frame(maxWidth: .infinity).padding(.bottom, 4)
            }.scrollIndicators(.hidden)
        }
    }
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "Good morning."
        case 12..<18: "Good afternoon."
        default: "Good evening."
        }
    }
    private func shortcut(_ page: MainWindowPage, detail: String) -> some View {
        Button { nav.select(page) } label: {
            HStack(spacing: 10) {
                Image(systemName: page.symbol).font(.system(size: 20))
                VStack(alignment: .leading, spacing: 5) {
                    Text(page.title(l)).fontWeight(.medium)
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
            }.padding(14).frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                .contentShape(Rectangle())
        }.buttonStyle(MainWindowShortcutStyle())
    }
    private var nextFocus: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.session == nil ? "Next focus" : l.currentFocus)
                .font(.system(size: 12)).foregroundStyle(.secondary)
            if let current = session.session {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(current.issue.identifier).font(.system(size: 12)).foregroundStyle(.secondary)
                        Text(current.issue.title).fontWeight(.medium).lineLimit(2)
                    }
                    Spacer()
                    Text(session.clockDisplay().text).monospacedDigit()
                    Button("Open Focus") { nav.select(.focus) }.tahoeButtonStyle(.prominent)
                }
            } else if let issue = usage.linearInProgressIssues.first {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(issue.identifier).font(.system(size: 12)).foregroundStyle(.secondary)
                        Text(issue.title).fontWeight(.medium).lineLimit(2)
                    }
                    Spacer()
                    LinearFocusButton(issue: issue, openDeskOnPin: false) { nav.select(.focus) }
                }
            } else {
                HStack {
                    Text(usage.linearAPIKeyConfigured ? "Choose an issue, or start a focus timer." : "Connect Linear to choose your next issue.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(usage.linearAPIKeyConfigured ? l.focusTab : l.settings) {
                        nav.select(usage.linearAPIKeyConfigured ? .focus : .settings)
                    }.tahoeButtonStyle(.regular)
                }
            }
        }.mainWindowCard()
    }
}

@MainActor
private struct MainWindowShortcutStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? MainWindowTheme(scheme: scheme).selected : MainWindowTheme(scheme: scheme).surface,
                                       in: RoundedRectangle(cornerRadius: 10))
    }
}

@MainActor
struct MainWindowCompanionHero: View {
    @Environment(CompanionStore.self) private var companion
    var size: CGFloat = 220
    var body: some View {
        VStack(spacing: 12) {
            SpriteView(speciesID: companion.currentSpeciesID, size: size, animated: true,
                       shiny: companion.currentIsShiny, cropToContent: true)
                .frame(height: size)
            HStack(spacing: 8) {
                Text(companion.state.trainingEmpty ? "Choose a Pokémon" : companion.displayName)
                    .font(.system(size: 20, weight: .semibold))
                if let rarity = companion.rarity {
                    Text(companion.l.rarityLabel(rarity)).font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(rarityColor(rarity).opacity(0.12), in: Capsule())
                        .foregroundStyle(rarityColor(rarity))
                }
            }
            Text(companion.stageText).font(.system(size: 12)).foregroundStyle(.secondary)
            if !companion.state.trainingEmpty {
                VStack(spacing: 7) {
                    ProgressView(value: companion.isEgg ? companion.eggProgress : companion.progress)
                        .progressViewStyle(MenuBarProgressStyle(tint: .blue)).controlSize(.small)
                    Text("\(TokenFormatter.compact(companion.isEgg ? companion.eggTokensToHatch : companion.tokensToNext)) XP to \(companion.isEgg ? "hatch" : companion.isFinalStage ? "graduation" : "evolution")")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }.frame(maxWidth: 290)
            }
        }.frame(maxWidth: .infinity)
    }
}
