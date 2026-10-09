import Foundation

/// Application Support state directory for PokeTaskBar files.
/// `PTB_STATE_DIR` overrides the default for development/QA isolation.
enum AppStatePaths {
    /// A renamed build can retain its save folder through `PTBStateFolderName`.
    /// Other bundled apps use `CFBundleName`; tests use v1 unless `PTB_STATE_DIR` overrides it.
    static var productFolderName: String {
        AppEnv.isBundledApp ? folderName(info: Bundle.main.infoDictionary ?? [:]) : "PokeTaskBar v1"
    }

    static func folderName(info: [String: Any]) -> String {
        for key in ["PTBStateFolderName", "CFBundleName"] {
            if let name = info[key] as? String {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
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
