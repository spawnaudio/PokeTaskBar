import SwiftUI

/// Pet + island while a session is running. Prompts sit above the island.
@MainActor
struct SessionIslandView: View {
    var onResizeTimer: (CGFloat, NSPoint) -> Void = { _, _ in }
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session

    private var l: L { companion.l }

    var body: some View {
        if session.pomodoroSetupOpen, session.session == nil {
            PomodoroSetupIsland(onResizeTimer: onResizeTimer)
        } else if let current = session.session {
            let width = store.floatingPetIslandFolded ? FloatingPetController.islandWidth : CGFloat(store.floatingTimerWidth)
            VStack(alignment: .leading, spacing: 6) {
                if let warning = session.forfeitPrompt {
                    FocusForfeitWarningCard(warning: warning)
                        .frame(width: width)
                } else if session.resetPrompt {
                    FocusResetConfirmCard()
                        .frame(width: width)
                } else if SessionPromptSurface.showsOnOverlay(floatingPetEnabled: store.floatingPetEnabled) {
                    SessionPromptCard()
                        .frame(width: width)
                }

                if session.isComposingNote, !current.issue.isPomodoro {
                    SessionNoteComposer()
                        .padding(8)
                        .frame(width: width, height: FloatingPetController.noteComposerHeight - 6)
                        .tahoeFloatingChrome()
                }
                if !store.floatingPetIslandFolded {
                    FloatingTimerStrip(onResizeTimer: onResizeTimer)
                }
            }
        }
    }
}

/// The same horizontal surface before a no-issue timer begins. Starting changes
/// the content without changing the user's width or moving the pet.
@MainActor
struct PomodoroSetupIsland: View {
    var onResizeTimer: (CGFloat, NSPoint) -> Void = { _, _ in }
    @Environment(UsageStore.self) private var store
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var hovering = false
    @State private var handleFocused = false

    private var l: L { companion.l }

    var body: some View {
        let theme = MenuBarTheme(scheme: scheme)
        HStack(spacing: 5) {
            dragHandle(.resize, label: l.resizeFloatingTimer)
                .frame(width: 12, height: 30)
                .overlay {
                    Capsule().fill(hovering || handleFocused ? theme.accent.opacity(0.6) : theme.border)
                        .frame(width: 2, height: 16)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            FloatingTimerClock()
                .frame(width: 74, alignment: .leading)
            Rectangle().fill(theme.border).frame(width: 1, height: 16).accessibilityHidden(true)
            Text(l.pomodoroTitle).font(.system(size: 11))
                .lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                ForEach(SessionXP.plannedPresets, id: \.self) { minutes in
                    Button(l.minutesValue(minutes)) {
                        session.plannedMinutes = minutes
                    }
                }
            } label: {
                Text(l.minutesValue(session.plannedMinutes)).font(.system(size: 11))
            }
            .menuStyle(.borderlessButton).fixedSize()
            .foregroundStyle(theme.secondary)
            Button { session.startPomodoro() } label: { Image(systemName: "play.fill") }
                .font(.system(size: 11))
                .buttonStyle(FloatingTimerButtonStyle(selected: true))
                .help(l.startPomodoro).accessibilityLabel(l.startPomodoro)
            FloatingTimerNewIssueButton()
            dragHandle(.move, label: l.moveFloatingTimer)
                .frame(width: 16, height: 30)
                .overlay {
                    Image(systemName: "circle.grid.2x2.fill")
                        .font(.system(size: 9)).foregroundStyle(theme.secondary)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
        }
        .padding(.horizontal, 4)
        .frame(width: CGFloat(store.floatingTimerWidth), height: FloatingTimerMetrics.height)
        .foregroundStyle(theme.text)
        .background(theme.canvas, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(
                contrast == .increased ? theme.secondary : theme.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .onHover { hovering = $0 }
    }

    private func dragHandle(_ mode: FloatingTimerDragView.Mode, label: String) -> some View {
        FloatingTimerDragHandle(mode: mode, width: CGFloat(store.floatingTimerWidth), label: label,
                                onResize: onResizeTimer, onFocusChange: { handleFocused = $0 })
            .help(label)
    }
}

/// Bubble button that expands the compact Linear comment field.
@MainActor
struct SessionNoteButton: View {
    var compact: Bool = true

    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }

    var body: some View {
        Group {
            if compact {
                Button {
                    session.toggleNoteComposer()
                } label: {
                    Image(systemName: session.isComposingNote ? "text.bubble.fill" : "text.bubble")
                }
                .tahoeButtonStyle(.accessory)
                .buttonBorderShape(.circle)
                .controlSize(.mini)
            } else {
                Button {
                    session.toggleNoteComposer()
                } label: {
                    Label(l.checkInAddNote, systemImage: session.isComposingNote ? "text.bubble.fill" : "text.bubble")
                }
                .tahoeButtonStyle(.regular)
                .controlSize(.small)
            }
        }
        .help(l.sessionNoteHelp)
    }
}

/// Compact field + Post. Shared by the overlay island and Today desk.
@MainActor
struct SessionNoteComposer: View {
    var compact: Bool = true

    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }
    @FocusState private var noteFieldFocused: Bool
    private var trimmedEmpty: Bool {
        session.noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        @Bindable var session = session
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(spacing: 6) {
                TextField(l.checkInNotePlaceholder, text: $session.noteDraft)
                    .textFieldStyle(.roundedBorder)
                    .focused($noteFieldFocused)
                    .onSubmit { Task { await session.postSessionNote() } }
                Button(l.postNote) {
                    Task { await session.postSessionNote() }
                }
                .tahoeButtonStyle(.prominent)
                .disabled(session.isPostingNote || trimmedEmpty)
            }
            if session.notePostFailed {
                Text(l.linearCommentFailed)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .controlSize(compact ? .mini : .small)
        .onAppear { noteFieldFocused = true }
    }
}
