import ServiceManagement

/// Local builds use macOS Open at Login. Distribution builds use the bundled
/// KeepAlive agent, which restarts abnormal exits but respects a normal Quit.
@MainActor
enum LoginItem {
    /// Derived from this bundle so a side-by-side build cannot steal the installed app's LaunchAgent.
    static var plistName: String { "\(bundleID).login.plist" }
    static var label: String { "\(bundleID).login" }
    private static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "io.github.spawnaudio.poketaskbar.v1"
    }
    private static var agent: SMAppService { SMAppService.agent(plistName: plistName) }
    private static var isLocalBuild: Bool { prefersMainApp(info: Bundle.main.infoDictionary ?? [:]) }
    private static var service: SMAppService { isLocalBuild ? .mainApp : agent }

    // Open at Login avoids the managed-agent constraint rejected for this local identity.
    static func prefersMainApp(info: [String: Any]) -> Bool {
        info["PTBDevelopmentBuild"] as? String == "1"
    }

    /// Whether this build's login service is enabled.
    static var isEnabled: Bool { service.status == .enabled }

    /// Registration errors surface through the Settings toggle.
    static func setEnabled(_ on: Bool) throws {
        if on { try service.register() } else { try service.unregister() }
    }

    static func migrateService(status: () -> SMAppService.Status, register: () throws -> Void,
                               unregisterPrevious: () throws -> Void) throws -> Bool {
        if status() != .enabled { try register() }
        guard status() == .enabled else { return false }
        try unregisterPrevious()
        return true
    }

    /// Register this build's login service before removing the previous one.
    /// Local builds use Open at Login; distribution builds retain the crash watchdog.
    static func migrateFromLegacyLoginItemIfNeeded() {
        let legacy = isLocalBuild ? agent : SMAppService.mainApp
        guard legacy.status == .enabled else { return }   // 구 로그인아이템 미사용 → 이관 불필요
        do {
            let current = service
            let migrated = try migrateService(status: { current.status }, register: { try current.register() },
                                              unregisterPrevious: { try legacy.unregister() })
            guard migrated else {
                AppLog.write("login item migration pending approval (previous service retained)")
                return
            }
            AppLog.write("login item migrated: \(isLocalBuild ? "Open at Login" : "KeepAlive agent")")
        } catch {
            AppLog.write("login item migration failed (previous service retained): \(error)")
        }
    }
}
