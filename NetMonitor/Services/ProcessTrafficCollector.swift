import Foundation
import AppKit
import Darwin

struct ProcessTrafficEntry {
    let processName: String
    let pid: Int32
    let bytesIn: Int64
    let bytesOut: Int64
}

final class ProcessTrafficCollector {

    func collectSample() async throws -> [ProcessTrafficEntry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        process.arguments = ["-P", "-d", "-x", "-l", "1", "-n"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return []
        }

        return parseOutput(data)
    }

    private func parseOutput(_ data: Data) -> [ProcessTrafficEntry] {
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var results: [ProcessTrafficEntry] = []
        let lines = output.components(separatedBy: "\n")

        // In -P mode, data lines have fixed fields:
        // [0] timestamp, [1] process.pid, [2] bytes_in, [3] bytes_out, [4..] other stats
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let parts = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard parts.count >= 4 else { continue }

            let processField = parts[1]
            guard let bytesIn = Int64(parts[2]),
                  let bytesOut = Int64(parts[3]) else { continue }

            if bytesIn == 0 && bytesOut == 0 { continue }

            let (name, pid) = parseProcessField(processField)

            results.append(ProcessTrafficEntry(
                processName: name,
                pid: pid,
                bytesIn: bytesIn,
                bytesOut: bytesOut
            ))
        }

        return results
    }

    private func parseProcessField(_ field: String) -> (name: String, pid: Int32) {
        // Format: "process_name.pid" or "process_name.123"
        guard let lastDot = field.lastIndex(of: ".") else {
            return (field, 0)
        }
        let name = String(field[field.startIndex..<lastDot])
        let pidStr = String(field[field.index(after: lastDot)...])
        let pid = Int32(pidStr) ?? 0
        return (name, pid)
    }

    func resolveBundleIdentifier(pid: Int32) -> String? {
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.bundleIdentifier
        }

        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(MAXPATHLEN))
        guard pathLen > 0 else { return nil }

        let path = String(cString: pathBuffer)
        return bundleIdentifierFromPath(path)
    }

    private func bundleIdentifierFromPath(_ path: String) -> String? {
        var url = URL(fileURLWithPath: path)
        while url.path != "/" {
            if url.pathExtension == "app" {
                if let bundle = Bundle(url: url) {
                    return bundle.bundleIdentifier
                }
            }
            url = url.deletingLastPathComponent()
        }
        return nil
    }
}
