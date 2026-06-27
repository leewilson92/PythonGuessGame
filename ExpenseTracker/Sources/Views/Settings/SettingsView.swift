import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 设置：数据备份（导出 / 导入）。v1 没有 iCloud 同步时的安全网。
/// 由「我的」Tab 的 `ProfileView` 以 `NavigationLink` push 进入，故不自带 `NavigationStack`/「完成」。
struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @State private var exporting = false
    @State private var importing = false
    @State private var exportDocument: BackupDocument?
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Button {
                    do {
                        let data = try BackupManager.export(from: context)
                        exportDocument = BackupDocument(data: data)
                        exporting = true
                    } catch {
                        message = "导出失败：\(error.localizedDescription)"
                    }
                } label: {
                    Label("导出备份", systemImage: "square.and.arrow.up")
                }

                Button {
                    importing = true
                } label: {
                    Label("导入备份", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("数据备份")
            } footer: {
                Text("导出后可存到 iCloud 文件、发给自己微信或邮箱。换手机时用「导入」恢复。导入会覆盖当前数据。")
            }

            if let message {
                Section { Text(message).font(.footnote) }
            }
        }
        .navigationTitle("数据备份")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "记账备份-\(Self.dateStamp)"
        ) { result in
            switch result {
            case .success: message = "导出成功"
            case .failure(let error): message = "导出失败：\(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                try BackupManager.restore(from: data, into: context)
                message = "导入成功"
            } catch {
                message = "导入失败：\(error.localizedDescription)"
            }
        case .failure(let error):
            message = "导入失败：\(error.localizedDescription)"
        }
    }

    private static var dateStamp: String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: .now)
    }
}

/// 用于 fileExporter 的简单 JSON 文档。
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
