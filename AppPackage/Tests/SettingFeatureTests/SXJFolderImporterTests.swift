import AppModels
import Foundation
import Testing
@testable import SettingFeature

struct SXJFolderImporterTests {
    @Test func emptyDirectoryDoesNotCreateDownloadedGallery() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        let destination = root.appendingPathComponent("downloads")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let importer = SXJFolderImporter(destinationRoot: destination)
        await #expect(throws: SXJFolderImporter.ImportError.self) {
            try await importer.importFolder(source, host: .ehentai)
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func invalidImageIsRejectedWithoutModifyingSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        let destination = root.appendingPathComponent("downloads")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let bytes = Data("not an image".utf8)
        let file = source.appendingPathComponent("001.png")
        try bytes.write(to: file)
        let importer = SXJFolderImporter(destinationRoot: destination)
        await #expect(throws: SXJFolderImporter.ImportError.self) {
            try await importer.importFolder(source, host: .ehentai)
        }
        #expect(try Data(contentsOf: file) == bytes)
        let imported = destination.appendingPathComponent("Imported")
        let remaining = try FileManager.default.contentsOfDirectory(atPath: imported.path)
        #expect(remaining.isEmpty)
    }
}
