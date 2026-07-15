import Foundation

struct SessionFallback: Sendable {
    let sessionsURL: URL
    let maximumFiles: Int
    let tailBytes: UInt64

    init(
        sessionsURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
            .appendingPathComponent("sessions"),
        maximumFiles: Int = 8,
        tailBytes: UInt64 = 4 * 1_024 * 1_024
    ) {
        self.sessionsURL = sessionsURL
        self.maximumFiles = maximumFiles
        self.tailBytes = tailBytes
    }

    func latestSnapshot() -> QuotaSnapshot? {
        let files = recentSessionFiles().prefix(maximumFiles)
        for file in files {
            guard let content = readTail(of: file.url) else { continue }
            for line in content.split(whereSeparator: \.isNewline).reversed() {
                if let snapshot = QuotaParser.parseSessionLine(String(line), updatedAt: file.modifiedAt) {
                    return snapshot
                }
            }
        }
        return nil
    }

    private func recentSessionFiles() -> [(url: URL, modifiedAt: Date)] {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [(URL, Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            result.append((url, values.contentModificationDate ?? .distantPast))
        }
        return result.sorted { $0.1 > $1.1 }
    }

    private func readTail(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            let size = try handle.seekToEnd()
            try handle.seek(toOffset: size > tailBytes ? size - tailBytes : 0)
            guard let data = try handle.readToEnd() else { return nil }
            return String(decoding: data, as: UTF8.self)
        } catch {
            return nil
        }
    }
}
