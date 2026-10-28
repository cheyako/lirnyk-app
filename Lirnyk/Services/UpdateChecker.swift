import Foundation

/// Dotted numeric version such as "0.2.0"; a leading "v" (as in release tags) is ignored.
nonisolated struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    let components: [Int]

    init?(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        let numbers = (trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed)
            .split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !numbers.isEmpty, !numbers.contains(nil) else { return nil }
        components = numbers.compactMap { $0 }
    }

    var description: String { components.map(String.init).joined(separator: ".") }

    /// Missing components count as zero, so "1.2" == "1.2.0".
    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        for index in 0..<max(lhs.components.count, rhs.components.count) {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool { !(lhs < rhs) && !(rhs < lhs) }
}

nonisolated enum UpdateCheckResult: Equatable, Sendable {
    case upToDate
    case available(version: String, url: URL)
}

nonisolated enum UpdateCheckError: Error, Equatable, Sendable {
    case network(String)
    case server(status: Int)
    case badResponse

    var message: String {
        switch self {
        case let .network(description): "Network error: \(description)"
        case let .server(status): "GitHub error \(status)"
        case .badResponse: "Unexpected answer from GitHub"
        }
    }
}

/// Compares the running version with the latest GitHub release.
/// Counted checks ask lirnyk.app first, which counts them anonymously (app and macOS version only) and answers
/// with the same fields as GitHub; when it fails, they ask GitHub directly.
final class UpdateChecker {
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/cheyako/lirnyk-app/releases/latest")!
    static let countedLatestURL = URL(string: "https://lirnyk.app/api/latest")!

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    private let session: URLSession
    private let currentVersion: String
    private let osMajorVersion: Int

    init(session: URLSession = .shared, currentVersion: String = UpdateChecker.currentVersion,
         osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) {
        self.session = session
        self.currentVersion = currentVersion
        self.osMajorVersion = osMajorVersion
    }

    func check(counted: Bool = false) async throws -> UpdateCheckResult {
        if counted, let result = try? await check(url: countedURL) { return result }
        return try await check(url: Self.latestReleaseURL)
    }

    var countedURL: URL {
        Self.countedLatestURL.appending(queryItems: [
            URLQueryItem(name: "v", value: currentVersion),
            URLQueryItem(name: "os", value: String(osMajorVersion)),
        ])
    }

    private func check(url: URL) async throws -> UpdateCheckResult {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UpdateCheckError.network(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw UpdateCheckError.server(status: status) }

        guard let release = try? JSONDecoder().decode(Release.self, from: data),
              let latest = AppVersion(release.tagName),
              let url = URL(string: release.htmlURL) else { throw UpdateCheckError.badResponse }
        guard let current = AppVersion(currentVersion), current < latest else { return .upToDate }
        return .available(version: latest.description, url: url)
    }
}

private nonisolated struct Release: Decodable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
