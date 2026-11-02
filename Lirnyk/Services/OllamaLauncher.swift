import Foundation
import Observation

/// Starts `ollama serve` on request and stops it again, at the latest when Lirnyk quits.
/// Only manages the server it started itself; an Ollama started elsewhere is left alone.
@Observable
final class OllamaLauncher {
    enum State: Equatable {
        case stopped
        case starting
        case running
        case failed(String)
    }

    /// Where Homebrew and the Ollama app put the CLI; apps launched from Finder don't get the shell's PATH.
    static let candidatePaths = [
        "/opt/homebrew/bin/ollama",
        "/usr/local/bin/ollama",
        "/Applications/Ollama.app/Contents/Resources/ollama",
        NSHomeDirectory() + "/Applications/Ollama.app/Contents/Resources/ollama",
    ]
    static let startTimeout: Duration = .seconds(15)

    private(set) var state = State.stopped
    private var process: Process?
    private let isExecutable: (String) -> Bool

    init(isExecutable: @escaping (String) -> Bool = FileManager.default.isExecutableFile(atPath:)) {
        self.isExecutable = isExecutable
    }

    /// Path of the installed `ollama` binary, if any.
    var executablePath: String? { Self.candidatePaths.first(where: isExecutable) }

    /// Only a server on this Mac can be started from Lirnyk.
    static func isLocal(_ server: String) -> Bool {
        guard let host = AIProvider.ollamaBaseURL(server)?.host() else { return false }
        return ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host.lowercased())
    }

    /// `OLLAMA_HOST` that makes the server listen where Settings points; nil keeps Ollama's default.
    static func listenAddress(_ server: String) -> String? {
        guard let url = AIProvider.ollamaBaseURL(server), let host = url.host(), let port = url.port else { return nil }
        return "\(host):\(port)"
    }

    func start(server: String) {
        guard process == nil else { return }
        guard let path = executablePath else {
            state = .failed("Ollama isn't installed.")
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["serve"]
        var environment = ProcessInfo.processInfo.environment
        if let address = Self.listenAddress(server) { environment["OLLAMA_HOST"] = address }
        process.environment = environment
        // Ollama logs heavily; an unread pipe would fill up and stall it.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] ended in
            let id = ObjectIdentifier(ended)
            let status = ended.terminationStatus
            Task { @MainActor in self?.processDidExit(id, status: status) }
        }
        do {
            try process.run()
        } catch {
            state = .failed("Couldn't start Ollama: \(error.localizedDescription)")
            return
        }
        self.process = process
        state = .starting
        Task { await waitUntilReady(process, server: server) }
    }

    func stop() {
        guard let process else { return }
        self.process = nil
        state = .stopped
        process.terminate()
    }

    /// Polls the server until it answers, so the model list can load once it's up.
    private func waitUntilReady(_ launched: Process, server: String) async {
        let deadline = ContinuousClock.now + Self.startTimeout
        while process === launched, ContinuousClock.now < deadline {
            if (try? await OllamaModels.installed(server: server)) != nil {
                if process === launched { state = .running }
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
        guard process === launched else { return }
        stop()
        state = .failed("Ollama didn't respond in time.")
    }

    private func processDidExit(_ id: ObjectIdentifier, status: Int32) {
        // A server we stopped on purpose has already been forgotten.
        guard let process, ObjectIdentifier(process) == id else { return }
        self.process = nil
        state = .failed("Ollama quit unexpectedly (exit code \(status)).")
    }
}
