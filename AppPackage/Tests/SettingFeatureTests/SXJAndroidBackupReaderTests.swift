import AppModels
import Foundation
import SQLite3
import Testing
@testable import SettingFeature

struct SXJAndroidBackupReaderTests {
    @Test func mapsExportedRecordsWithoutWritingToSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("export.db")
        try database(at: source, sql: """
        CREATE TABLE LOCAL_FAVORITES (GID INTEGER, TOKEN TEXT, TITLE TEXT, CATEGORY INTEGER, TIME INTEGER, THUMB TEXT);
        INSERT INTO LOCAL_FAVORITES VALUES (123,'abcdef1234','Sample',4,1700000000000,'file:///private/cover.png');
        CREATE TABLE HISTORY (GID INTEGER, TOKEN TEXT, TIME INTEGER);
        INSERT INTO HISTORY VALUES (123,'abcdef1234',1700000000000);
        CREATE TABLE BOOKMARKS (GID INTEGER, TOKEN TEXT, PAGE INTEGER, TIME INTEGER);
        INSERT INTO BOOKMARKS VALUES (123,'abcdef1234',4,1700000001000);
        CREATE TABLE FILTER (MODE INTEGER, TEXT TEXT, ENABLE INTEGER);
        INSERT INTO FILTER VALUES (1,'sample uploader',0);
        CREATE TABLE QUICK_SEARCH (NAME TEXT, KEYWORD TEXT, TIME INTEGER);
        INSERT INTO QUICK_SEARCH VALUES ('sample search','language:chinese',1);
        CREATE TABLE DOWNLOADS (GID INTEGER);
        INSERT INTO DOWNLOADS VALUES (123),(456);
        """)
        let original = try Data(contentsOf: source)
        let plan = try await SXJAndroidBackupReader().read(source, host: .ehentai)
        #expect(plan.favorites.count == 1)
        #expect(plan.favorites.first?.gid == "123")
        #expect(plan.favorites.first?.category == .manga)
        #expect(plan.favorites.first?.coverURL == nil)
        #expect(plan.history.first?.readingProgress == 5)
        #expect(plan.rules.first?.kind == .uploader)
        #expect(plan.rules.first?.isEnabled == false)
        #expect(plan.searches.first?.content == "language:chinese")
        #expect(plan.downloadRecords == 2)
        #expect(try Data(contentsOf: source) == original)
    }

    @Test func rejectsUnknownDatabaseAndNonDatabaseInput() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("unrelated.db")
        try database(at: source, sql: "CREATE TABLE unrelated (value TEXT)")
        await #expect(throws: SXJAndroidBackupReader.ImportError.self) {
            try await SXJAndroidBackupReader().read(source, host: .ehentai)
        }
        try Data("not a SQLite database".utf8).write(to: source)
        await #expect(throws: SXJAndroidBackupReader.ImportError.self) {
            try await SXJAndroidBackupReader().read(source, host: .ehentai)
        }
    }

    @Test func rejectsRecordOverflowInsteadOfSilentlyDroppingHistory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("large.db")
        try database(at: source, sql: """
        CREATE TABLE HISTORY (GID INTEGER, TOKEN TEXT, TIME INTEGER);
        WITH RECURSIVE ids(value) AS (SELECT 1 UNION ALL SELECT value+1 FROM ids WHERE value<1001)
        INSERT INTO HISTORY SELECT value,'abcdef1234',value FROM ids;
        """)
        await #expect(throws: SXJAndroidBackupReader.ImportError.self) {
            try await SXJAndroidBackupReader().read(source, host: .ehentai)
        }
    }

    private func database(at url: URL, sql: String) throws {
        var connection: OpaquePointer?
        try #require(sqlite3_open(url.path, &connection) == SQLITE_OK)
        let database = try #require(connection)
        defer { sqlite3_close(database) }
        try #require(sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK)
    }
}
