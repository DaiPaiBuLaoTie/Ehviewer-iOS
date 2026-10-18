import AppModels
import Foundation
import SQLite3

struct SXJAndroidBackupPlan: Sendable {
    var favorites: [Gallery] = []
    var history: [GalleryHistoryEntry] = []
    var rules: [SXJBlockRule] = []
    var searches: [QuickSearchWord] = []
    var downloadRecords = 0
    var hasAdvancedSearches = false
}

/// Reads a private snapshot of the Android export. It never opens the user's original database for writing.
actor SXJAndroidBackupReader {
    func read(_ source: URL, host: GalleryHost) throws -> SXJAndroidBackupPlan {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshot = root.appendingPathComponent("backup.db")
        var failure: Error?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: source, error: &coordinationError) { localURL in
            do {
                let values = try localURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true, let size = values.fileSize, size <= 128 * 1_024 * 1_024
                else { throw ImportError.invalidDatabase }
                try FileManager.default.copyItem(at: localURL, to: snapshot)
            } catch { failure = error }
        }
        if let coordinationError { throw coordinationError }
        if let failure { throw failure }
        let handle = try FileHandle(forReadingFrom: snapshot)
        let signature = try handle.read(upToCount: 16)
        try handle.close()
        guard signature == Data("SQLite format 3\0".utf8) else { throw ImportError.invalidDatabase }
        var connection: OpaquePointer?
        let result = sqlite3_open_v2(snapshot.path, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        guard result == SQLITE_OK, let database = connection else {
            if let connection { sqlite3_close(connection) }
            throw ImportError.invalidDatabase
        }
        defer { sqlite3_close(database) }
        sqlite3_limit(database, SQLITE_LIMIT_LENGTH, 1_048_576)
        sqlite3_limit(database, SQLITE_LIMIT_SQL_LENGTH, 65_536)
        guard sqlite3_exec(database, "PRAGMA trusted_schema=OFF; PRAGMA query_only=ON", nil, nil, nil) == SQLITE_OK
        else { throw ImportError.invalidDatabase }
        let tables = try rows(database, sql: "SELECT name FROM sqlite_master WHERE type='table'", maximum: 100)
        let names = Set(tables.compactMap { $0["name"] })
        guard !names.isDisjoint(with: ["LOCAL_FAVORITES", "HISTORY", "BOOKMARKS", "FILTER", "QUICK_SEARCH"])
        else { throw ImportError.unsupported }
        var plan = SXJAndroidBackupPlan()
        if names.contains("LOCAL_FAVORITES") {
            plan.favorites = try rows(
                database, sql: "SELECT * FROM LOCAL_FAVORITES ORDER BY TIME DESC", maximum: 1_000
            ).map { try gallery($0, host: host) }
        }
        var history: [String: GalleryHistoryEntry] = [:]
        if names.contains("HISTORY") {
            let records = try rows(
                database, sql: "SELECT GID,TOKEN,TIME FROM HISTORY ORDER BY TIME DESC", maximum: 1_000
            )
            for row in records {
                let identity = try self.identity(row)
                history[identity.gid] = GalleryHistoryEntry(
                    gid: identity.gid, token: identity.token, lastOpenDate: date(row["TIME"])
                )
            }
        }
        if names.contains("BOOKMARKS") {
            let bookmarks = try rows(
                database, sql: "SELECT GID,TOKEN,PAGE,TIME FROM BOOKMARKS ORDER BY TIME DESC", maximum: 1_000
            )
            for row in bookmarks {
                let identity = try self.identity(row)
                let progress = min(max(Int(row["PAGE"] ?? "") ?? 0, 0), 100_000) + 1
                history[identity.gid] = GalleryHistoryEntry(
                    gid: identity.gid, token: identity.token,
                    lastOpenDate: max(history[identity.gid]?.lastOpenDate ?? .distantPast, date(row["TIME"])),
                    readingProgress: progress
                )
            }
        }
        plan.history = history.values.sorted { $0.lastOpenDate > $1.lastOpenDate }
        if names.contains("FILTER") {
            let modes: [Int: SXJBlockRule.Kind] = [0: .title, 1: .uploader, 2: .tag, 3: .namespace]
            for row in try rows(database, sql: "SELECT MODE,TEXT,ENABLE FROM FILTER", maximum: 2_000) {
                guard let mode = Int(row["MODE"] ?? ""), let kind = modes[mode],
                      let text = row["TEXT"], !text.isEmpty, text.count <= 1_000
                else { throw ImportError.invalidRecords }
                plan.rules.append(SXJBlockRule(kind: kind, value: text, isEnabled: row["ENABLE"] != "0"))
            }
        }
        if names.contains("QUICK_SEARCH") {
            for row in try rows(database, sql: "SELECT * FROM QUICK_SEARCH ORDER BY TIME", maximum: 1_000) {
                let name = row["NAME"] ?? ""
                let keyword = row["KEYWORD"] ?? ""
                guard name.count <= 1_000, keyword.count <= 4_000 else { throw ImportError.invalidRecords }
                if !name.isEmpty || !keyword.isEmpty { plan.searches.append(.init(name: name, content: keyword)) }
                plan.hasAdvancedSearches = true
            }
        }
        if names.contains("DOWNLOADS") {
            let counts = try rows(database, sql: "SELECT COUNT(*) AS count FROM DOWNLOADS", maximum: 1)
            plan.downloadRecords = Int(counts.first?["count"] ?? "") ?? 0
        }
        return plan
    }

    private func rows(_ database: OpaquePointer, sql: String, maximum: Int) throws -> [[String: String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw ImportError.unsupported
        }
        defer { sqlite3_finalize(statement) }
        var result: [[String: String]] = []
        while true {
            try Task.checkCancellation()
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw ImportError.invalidDatabase }
            guard result.count < maximum else { throw ImportError.tooManyRecords }
            var row: [String: String] = [:]
            for index in 0..<sqlite3_column_count(statement) {
                guard let name = sqlite3_column_name(statement, index),
                      let value = sqlite3_column_text(statement, index)
                else { continue }
                row[String(cString: name)] = String(cString: value)
            }
            result.append(row)
        }
    }

    private func identity(_ row: [String: String]) throws -> (gid: String, token: String) {
        guard let gid = Int64(row["GID"] ?? ""), gid > 0, let token = row["TOKEN"], !token.isEmpty,
              token.count <= 128, token.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "-_".contains($0)) })
        else { throw ImportError.invalidRecords }
        return (String(gid), token)
    }

    private func date(_ value: String?) -> Date {
        guard let milliseconds = Int64(value ?? ""), milliseconds >= 0 else { return .distantPast }
        return min(Date(timeIntervalSince1970: Double(milliseconds) / 1_000), Date())
    }

    private func postedDate(_ value: String?) -> Date {
        guard let value else { return .distantPast }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: value) ?? .distantPast
    }

    private func gallery(_ row: [String: String], host: GalleryHost) throws -> Gallery {
        let identity = try self.identity(row)
        let categories: [Int: AppModels.Category] = [
            1: .misc, 2: .doujinshi, 4: .manga, 8: .artistCG, 16: .gameCG,
            32: .imageSet, 64: .cosplay, 128: .asianPorn, 256: .nonH, 512: .western
        ]
        let title = row["TITLE"] ?? row["TITLE_JPN"] ?? identity.gid
        guard title.count <= 4_000 else { throw ImportError.invalidRecords }
        var cover: URL?
        if let raw = row["THUMB"], let url = URL(string: raw),
           ["https", "http"].contains(url.scheme ?? ""), url.host != nil, url.user == nil, url.password == nil {
            cover = url
        }
        let rating = Float(row["RATING"] ?? "") ?? 0
        return Gallery(
            gid: identity.gid, token: identity.token, title: title,
            rating: rating.isFinite ? min(max(rating, 0), 5) : 0, tags: [],
            category: categories[Int(row["CATEGORY"] ?? "") ?? 1] ?? .misc,
            uploader: row["UPLOADER"], pageCount: 1, postedDate: postedDate(row["POSTED"]), coverURL: cover,
            galleryURL: host.url.appendingPathComponent("g/" + identity.gid + "/" + identity.token + "/")
        )
    }

    enum ImportError: LocalizedError {
        case invalidDatabase
        case unsupported
        case invalidRecords
        case tooManyRecords

        var errorDescription: String? {
            switch self {
            case .invalidDatabase: return "不是有效的 Android SQLite 导出，或文件超过 128 MB。请使用原版导出的 .db 文件。"
            case .unsupported: return "数据库表结构不兼容；未导入任何数据。"
            case .invalidRecords: return "数据库中存在无效画廊身份或记录；未导入任何数据。"
            case .tooManyRecords: return "记录超出单次迁移上限；未导入任何数据。请先在原版中整理后重新导出。"
            }
        }
    }
}
