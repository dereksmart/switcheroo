import Foundation

enum HostsFileError: Error, LocalizedError {
    case readFailed(String)
    case writeFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .readFailed(let m): return "Couldn't read /etc/hosts: \(m)"
        case .writeFailed(let m): return "Couldn't save: \(m)"
        case .cancelled: return "Authorization cancelled"
        }
    }
}

enum HostsFile {
    static let path = "/etc/hosts"

    static func read() throws -> String {
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw HostsFileError.readFailed(error.localizedDescription)
        }
    }

    private static let helperPath = "/usr/local/bin/switcheroo-save"

    /// Writes `contents` to /etc/hosts and flushes DNS. If the passwordless
    /// helper (scripts/install-privileged.sh) is installed, uses that and
    /// prompts for nothing. Otherwise falls back to osascript, which shows
    /// the standard admin password prompt.
    static func write(_ contents: String) async throws {
        if FileManager.default.isExecutableFile(atPath: helperPath) {
            do {
                try await writeViaHelper(contents)
                await runPostSaveCommand()
                return
            } catch HostsFileError.writeFailed(let msg) where msg.contains("password is required") || msg.contains("sudo: a") {
                // Helper exists but sudoers isn't set up — fall through to prompt.
            }
        }
        try await writeViaOsascript(contents)
        await runPostSaveCommand()
    }

    private static func runPostSaveCommand() async {
        guard let cmd = Settings.postSaveCommand else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", cmd]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in cont.resume() }
            do { try process.run() } catch { cont.resume() }
        }
    }

    private static func writeViaHelper(_ contents: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", helperPath]

        let stdin = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardError = stderr
        process.standardOutput = Pipe()

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { p in
                if p.terminationStatus == 0 {
                    cont.resume()
                    return
                }
                let errStr = String(
                    data: stderr.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                cont.resume(throwing: HostsFileError.writeFailed(
                    errStr.isEmpty ? "helper exit \(p.terminationStatus)" : errStr
                ))
            }
            do {
                try process.run()
                if let data = contents.data(using: .utf8) {
                    try stdin.fileHandleForWriting.write(contentsOf: data)
                }
                try stdin.fileHandleForWriting.close()
            } catch {
                cont.resume(throwing: HostsFileError.writeFailed(error.localizedDescription))
            }
        }
    }

    private static func writeViaOsascript(_ contents: String) async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("switcheroo-hosts-\(UUID().uuidString)")
        do {
            try contents.write(to: tmp, atomically: true, encoding: .utf8)
        } catch {
            throw HostsFileError.writeFailed(error.localizedDescription)
        }
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Save + flush. We restart mDNSResponder (SIGTERM → launchd respawns it)
        // rather than SIGHUP'ing it, because HUP only reloads config; existing
        // cached DNS answers still win over a newly-added /etc/hosts entry.
        let shell = "cp \(shellQuote(tmp.path)) /etc/hosts && chmod 644 /etc/hosts && chown root:wheel /etc/hosts; dscacheutil -flushcache; killall mDNSResponder; killall mDNSResponderHelper 2>/dev/null || true"
        let script = "do shell script \"\(escapeForAppleScript(shell))\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = Pipe()

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { p in
                if p.terminationStatus == 0 {
                    cont.resume()
                    return
                }
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                if errStr.contains("User canceled") || errStr.contains("-128") {
                    cont.resume(throwing: HostsFileError.cancelled)
                } else {
                    let msg = errStr.isEmpty ? "exit \(p.terminationStatus)" : errStr
                    cont.resume(throwing: HostsFileError.writeFailed(msg))
                }
            }
            do {
                try process.run()
            } catch {
                cont.resume(throwing: HostsFileError.writeFailed(error.localizedDescription))
            }
        }
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
