import AppKit
import Observation

/// GitHub 릴리스 최신 버전을 확인해 새 버전이 있으면 팝오버에 알린다.
/// 실제 설치는 brew 사용자면 `brew upgrade`, 그 외엔 릴리스 페이지 열기(저위험·인프라 0).
@MainActor
@Observable
final class UpdateChecker {
    struct Available: Equatable { let version: String; let url: String }

    /// What Settings should say after a check. A skipped release is not "up to date".
    enum SettingsNotice: Equatable {
        case offer(String)
        case skipped(String)
        case current
    }

    private(set) var available: Available?
    /// Newer release the user chose to skip. Hidden from the banner, still shown in Settings.
    private(set) var skipped: Available?
    private(set) var isUpdating = false

    let currentVersion: String
    private let repo = "spawnaudio/PokeTaskBar"
    private let clock: () -> Date
    private let defaults: UserDefaults
    private var lastChecked: Date?

    static let skippedVersionKey = "skippedUpdateVersion"

    init(currentVersion: String? = nil, clock: @escaping () -> Date = Date.init, defaults: UserDefaults = .standard) {
        self.currentVersion = currentVersion
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
        self.clock = clock
        self.defaults = defaults
    }

    var settingsNotice: SettingsNotice {
        if let available { return .offer(available.version) }
        if let skipped { return .skipped(skipped.version) }
        return .current
    }

    /// Release Settings can install. A skip hides the banner; it does not throw the URL away.
    var updateTarget: Available? { available ?? skipped }

    /// 최신 릴리스 조회. 스킵한 버전은 배너(`available`)에 안 올리고 Settings(`skipped`)에만 남긴다.
    /// minInterval 보다 자주 호출되면 무시(레이트리밋 보호).
    func check(minInterval: TimeInterval = 1800) async {
        if let last = lastChecked, clock().timeIntervalSince(last) < minInterval { return }
        lastChecked = clock()
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let html = json["html_url"] as? String,
              // 응답 필드가 NSWorkspace.open 으로 가므로 https + github.com 만 허용(스킴 하이재킹 방지)
              let htmlURL = URL(string: html), htmlURL.scheme == "https", htmlURL.host == "github.com"
        else { return }
        consider(latest: tag, url: html)
    }

    /// Apply one fetched release. `latest` may be a tag (`v2.5.4`) or a bare version.
    func consider(latest tag: String, url: String) {
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let skippedVersion = defaults.string(forKey: Self.skippedVersionKey)
        guard Self.isNewer(latest, than: currentVersion) else {
            available = nil
            skipped = nil
            return
        }
        let release = Available(version: latest, url: url)
        if latest == skippedVersion {
            available = nil
            skipped = release
        } else {
            available = release
            skipped = nil
        }
    }

    /// Hide the banner for this version. Settings can still see it and install it.
    func skipCurrent() {
        guard let release = available else { return }
        defaults.set(release.version, forKey: Self.skippedVersionKey)
        skipped = release
        available = nil
    }

    /// Undo a skip so the banner can show the same release again.
    func showSkippedAgain() {
        defaults.removeObject(forKey: Self.skippedVersionKey)
        if let release = skipped {
            available = release
            skipped = nil
        }
    }

    /// Open the GitHub release. PokeTaskBar v1 has no Homebrew cask (and must not
    /// upgrade `poke-token-bar`, which is a different app).
    func applyUpdate() {
        guard let update = updateTarget, !isUpdating else { return }
        AppLog.write("update: open GitHub release")
        if let u = URL(string: update.url) { NSWorkspace.shared.open(u) }
    }

    // MARK: 버전 비교

    /// a 가 b 보다 높은 semver 인가. ("2.0.10" > "2.0.9" 등 숫자 비교)
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Wait for this PID, then reopen via login agent ($4) or `open` ($2).
    /// $1 unused (kept so callers can pass brew without interpolation). $3 is the pid.
    nonisolated static let detachedUpgradeScript = """
    for i in $(seq 1 40); do kill -0 "$3" 2>/dev/null || break; sleep 0.5; done
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    for i in $(seq 1 15); do
      launchctl kickstart -k "gui/$(id -u)/$4" 2>/dev/null && break
      open "$2" 2>/dev/null && break
      sleep 1
    done
    """

    nonisolated static func launchDetachedUpgrade(
        brew: String,
        pid: pid_t = ProcessInfo.processInfo.processIdentifier,
        bundlePath: String = Bundle.main.bundlePath,
        loginLabel: String = "io.github.spawnaudio.poketaskbar.v1.login"
    ) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", detachedUpgradeScript, "sh", brew, bundlePath, String(pid), loginLabel]
        try? task.run()
    }
}
