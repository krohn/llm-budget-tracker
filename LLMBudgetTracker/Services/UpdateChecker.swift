import Foundation
import Observation

/// Checks GitHub for a newer release, on demand and (if enabled) once a day.
@Observable
@MainActor
final class UpdateChecker {
    private static let autoCheckPollSeconds: Double = 60 * 60

    var autoCheckEnabled: Bool =
        UserDefaults.standard.object(forKey: StorageKeys.App.updateCheckEnabled) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(autoCheckEnabled, forKey: StorageKeys.App.updateCheckEnabled)
            startAutoCheck()
        }
    }

    private(set) var status: UpdateCheckStatus = .idle
    private(set) var lastCheck: Date? = UserDefaults.standard.object(forKey: StorageKeys.App.lastUpdateCheck) as? Date {
        didSet { UserDefaults.standard.set(lastCheck, forKey: StorageKeys.App.lastUpdateCheck) }
    }

    @ObservationIgnored private var autoCheckTask: Task<Void, Never>?
    @ObservationIgnored private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    func checkNow() async {
        guard status != .checking, let url = ReleaseFeed.latestReleaseURL else { return }
        status = .checking
        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let release = try JSONDecoder().decode(LatestRelease.self, from: data)
            status = ReleaseFeed.status(latestTag: release.tagName, currentVersion: currentVersion)
            lastCheck = Date()
        } catch {
            status = .failed("Could not check for updates: \(error.localizedDescription)")
        }
    }

    /// Checks once at launch, then whenever the last successful check is a day old.
    /// Polls hourly instead of sleeping 24 h so a sleeping Mac does not delay the check.
    func startAutoCheck() {
        autoCheckTask?.cancel()
        guard autoCheckEnabled else { return }
        autoCheckTask = Task { [weak self] in
            await self?.checkNow()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.autoCheckPollSeconds))
                guard let self, !Task.isCancelled else { return }
                if ReleaseFeed.isCheckDue(lastCheck: lastCheck, now: Date()) {
                    await checkNow()
                }
            }
        }
    }
}
