import AppModels
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Portable app preferences; cookies, passwords and downloaded images are excluded.
struct SXJBackup: Codable {
    var format = "ehviewer-sxj-ios"
    var version = 1
    var creationDate = Date()
    var setting: Setting
    var searchFilter: Filter
    var globalFilter: Filter
    var watchedFilter: Filter
    var historyKeywords: [String]
    var quickSearchWords: [QuickSearchWord]
    var galleryHistory: [GalleryHistoryEntry]
    var blockRules: [SXJBlockRule]
    var localFavorites: [Gallery]?

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 16 * 1_024 * 1_024 else { throw BackupError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Self.self, from: data)
        guard backup.format == "ehviewer-sxj-ios", backup.version == 1 else { throw BackupError.unsupported }
        guard backup.galleryHistory.count <= 10_000,
              backup.historyKeywords.count <= 1_000,
              backup.quickSearchWords.count <= 1_000,
              backup.blockRules.count <= 2_000,
              (backup.localFavorites?.count ?? 0) <= 1_000,
              Set(backup.blockRules.map(\.id)).count == backup.blockRules.count,
              Set(backup.quickSearchWords.map(\.id)).count == backup.quickSearchWords.count,
              Set(backup.galleryHistory.map(\.gid)).count == backup.galleryHistory.count
        else { throw BackupError.invalidRecords }
        return backup
    }

    enum BackupError: LocalizedError {
        case tooLarge
        case unsupported
        case invalidRecords

        var errorDescription: String? {
            switch self {
            case .tooLarge: return "备份超过 16 MB，请选择应用导出的 JSON 备份。"
            case .unsupported: return "备份格式或版本不受支持。Android 数据库需要先转换，不能直接作为此备份导入。"
            case .invalidRecords: return "备份含重复标识或超出记录上限，未修改当前数据。"
            }
        }
    }
}

struct SXJBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data = Data()) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
