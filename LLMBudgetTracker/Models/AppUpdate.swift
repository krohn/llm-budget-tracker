import Foundation

/// A release version in `major.minor.patch` form, optionally prefixed with `v` as in Git tags.
struct AppVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init?(_ string: String) {
        var trimmed = Substring(string.trimmingCharacters(in: .whitespaces))
        if trimmed.hasPrefix("v") { trimmed = trimmed.dropFirst() }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard parts.count == 3,
              let major = parts[0], let minor = parts[1], let patch = parts[2],
              major >= 0, minor >= 0, patch >= 0 else { return nil }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    var description: String { "\(major).\(minor).\(patch)" }
}

/// The fields of `GET /projects/:id/releases/permalink/latest` the update check needs.
struct LatestRelease: Decodable {
    let tagName: String

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
    }
}

enum UpdateCheckStatus: Equatable {
    case idle
    case checking
    case upToDate
    case updateAvailable(version: String, url: URL)
    case failed(String)
}

enum ReleaseFeed {
    static let latestReleaseURL = URL(
        string: "https://git.krohn.io/api/v4/projects/karsten%2Fllm-budget-tracker/releases/permalink/latest"
    )
    static let autoCheckInterval: TimeInterval = 24 * 60 * 60

    /// Release page for a tag. Built from a fixed https base because the API returns `http` links.
    static func releasePageURL(tag: String) -> URL? {
        URL(string: "https://git.krohn.io/karsten/llm-budget-tracker/-/releases/\(tag)")
    }

    static func isCheckDue(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= autoCheckInterval
    }

    static func status(latestTag: String, currentVersion: String) -> UpdateCheckStatus {
        guard let latest = AppVersion(latestTag), let current = AppVersion(currentVersion) else {
            return .failed("Unexpected version format: \(latestTag)")
        }
        guard latest > current else { return .upToDate }
        guard let url = releasePageURL(tag: latestTag) else {
            return .failed("Invalid release page for \(latestTag)")
        }
        return .updateAvailable(version: latest.description, url: url)
    }
}
