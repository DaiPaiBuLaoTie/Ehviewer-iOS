import AppModels
import ComposableArchitecture
import DownloadClient
import Sharing
import SwiftUI
import UniformTypeIdentifiers

struct SXJLocalImportView: View {
    @SharedReader(.setting) private var setting: Setting
    @Dependency(\.downloadClient) private var downloadClient
    @State private var choosing = false
    @State private var working = false
    @State private var status: String?
    private let importer = SXJFolderImporter()

    var body: some View {
        Form {
            Section("导入图片目录") {
                Button("从“文件”选择目录") { choosing = true }
                    .disabled(working)
                    .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { result in
                        beginImport(result)
                    }
                if working { ProgressView("正在复制和校验图片…") }
                Text("选择一个画廊或包含多个画廊的目录。图片按文件名自然排序，导入后在“下载”的 Imported 文件夹中离线阅读。原文件会保留。")
                Text("支持 JPEG、PNG、GIF、WebP、AVIF、HEIC 等系统可解码图片。ZIP、7z、RAR 请先解压。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let status { Section { Text(status) } }
        }
        .navigationTitle("本地画廊导入")
    }

    private func beginImport(_ result: Result<URL, Error>) {
        do {
            let source = try result.get()
            working = true
            status = nil
            let host = setting.galleryHost
            Task {
                do {
                    let count = try await importer.importFolder(source, host: host)
                    await downloadClient.refreshDownloads()
                    status = "导入完成，画廊数量：" + String(count)
                } catch {
                    await downloadClient.refreshDownloads()
                    status = error.localizedDescription + " 已完成的画廊仍保留在下载列表。"
                }
                working = false
            }
        } catch { status = error.localizedDescription }
    }
}
