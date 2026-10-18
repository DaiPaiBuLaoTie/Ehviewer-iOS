import Foundation

/// Compatibility with Android SpiderInfo v1/v2 headers. Page tokens are never needed for local image imports.
struct SXJAndroidDownloadHeader: Equatable, Sendable {
    let gid: String
    let token: String
    let pageCount: Int

    static func read(folder: URL) throws -> Self? {
        let file = folder.appendingPathComponent(".ehviewer")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw HeaderError.invalid }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 16_384) ?? Data()
        return try parse(data)
    }

    static func parse(_ data: Data) throws -> Self {
        guard let text = String(bytes: data, encoding: .utf8) else { throw HeaderError.invalid }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(8).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let first = lines.first else { throw HeaderError.invalid }
        let offset: Int
        if first == "VERSION2" {
            offset = 1
        } else {
            guard !first.hasPrefix("VERSION"), first.count == 8,
                  UInt32(first, radix: 16) != nil
            else { throw HeaderError.invalid }
            offset = 0
        }
        guard lines.count >= offset + 7,
              let identity = Int64(lines[offset + 1]), identity > 0,
              let count = Int(lines[offset + 6]), count > 0, count <= 20_000
        else { throw HeaderError.invalid }
        let token = lines[offset + 2]
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard !token.isEmpty, token.count <= 128, token.unicodeScalars.allSatisfy({ allowed.contains($0) })
        else { throw HeaderError.invalid }
        return Self(gid: String(identity), token: token, pageCount: count)
    }

    enum HeaderError: LocalizedError {
        case invalid

        var errorDescription: String? {
            "Android .ehviewer 元数据无效或页数超过导入上限，未写入该画廊。"
        }
    }
}
