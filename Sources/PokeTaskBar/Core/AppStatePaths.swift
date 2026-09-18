import Foundation

/// Application Support state directory for PokeTaskBar files.
/// `PTB_STATE_DIR` overrides the default for development/QA isolation.
enum AppStatePaths {
    /// Finder/menu-bar name and on-disk folder. Bundled apps use `CFBundleName` so a side-by-side
    /// install (`PokeTaskBar v1` vs `PokeTokenBar v3`) does not share saves. Tests and `swift run`
    /// use the same v1 folder name unless `PTB_STATE_DIR` overrides it.
    static var productFolderName: String {
        if AppEnv.isBundledApp,
           let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "PokeTaskBar v1"
    }

    static func directory() -> URL {
        let override = (ProcessInfo.processInfo.environment["PTB_STATE_DIR"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let dir: URL
        if !override.isEmpty {
            dir = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(productFolderName)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
