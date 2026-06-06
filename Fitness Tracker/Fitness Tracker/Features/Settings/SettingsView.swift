internal import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The Settings tab: export a full JSON backup, or restore from one (which
/// replaces everything currently in the app). Since data is local-only on a free
/// account, this is the user's manual backup.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppSettings.leadSideKey) private var leadSide = SetSide.right.rawValue
    @AppStorage(AppSettings.effortScaleKey) private var effortScale = EffortScale.rpe.rawValue
    @AppStorage(AppSettings.logLayoutKey) private var logLayout = LogLayout.compact.rawValue

    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var confirmRestore = false
    @State private var pendingRestoreURL: URL?
    @State private var status: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Lead arm", selection: $leadSide) {
                        Text("Right first").tag(SetSide.right.rawValue)
                        Text("Left first").tag(SetSide.left.rawValue)
                    }
                    Picker("Effort scale", selection: $effortScale) {
                        Text("RPE").tag(EffortScale.rpe.rawValue)
                        Text("RIR").tag(EffortScale.rir.rawValue)
                    }
                    Picker("Set controls", selection: $logLayout) {
                        ForEach(LogLayout.allCases) { layout in
                            Text(layout.label).tag(layout.rawValue)
                        }
                    }
                } header: {
                    Text("Logging")
                } footer: {
                    Text("Lead arm: which side is selected and pre-created first for unilateral exercises. Effort scale: RPE (10 = failure) or RIR (0 = failure, reps in reserve). Set controls: \(layoutDetail).")
                }

                Section {
                    Button {
                        startExport()
                    } label: {
                        Label("Export backup…", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        isImporting = true
                    } label: {
                        Label("Restore from file…", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Export saves all workouts, plans, and exercises to a JSON file you can store in Files or iCloud Drive. Restore replaces everything in the app with that file's contents. Your data lives only on this device, so back up regularly.")
                }

                if let status {
                    Section {
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: defaultFilename()
            ) { result in
                switch result {
                case .success: status = "Backup exported."
                case .failure(let error): status = "Export failed: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    pendingRestoreURL = url
                    confirmRestore = true
                case .failure(let error):
                    status = "Couldn't open file: \(error.localizedDescription)"
                }
            }
            .confirmationDialog("Replace all data with this backup?", isPresented: $confirmRestore, titleVisibility: .visible) {
                Button("Replace everything", role: .destructive) { performRestore() }
                Button("Cancel", role: .cancel) { pendingRestoreURL = nil }
            } message: {
                Text("This erases your current workouts, plans, and exercises, then imports the file. It can't be undone.")
            }
        }
    }

    /// Footer hint describing the currently selected logging layout.
    private var layoutDetail: String {
        (LogLayout(rawValue: logLayout) ?? .compact).detail
    }

    private func startExport() {
        do {
            exportDocument = BackupDocument(data: try BackupService.export(modelContext))
            isExporting = true
        } catch {
            status = "Export failed: \(error.localizedDescription)"
        }
    }

    private func performRestore() {
        guard let url = pendingRestoreURL else { return }
        defer { pendingRestoreURL = nil }
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            try BackupService.restore(from: data, into: modelContext)
            status = "Restore complete."
        } catch {
            status = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func defaultFilename() -> String {
        "FitnessTracker-\(Date().formatted(.iso8601.year().month().day()))"
    }
}

/// Wraps the backup JSON so SwiftUI's `fileExporter` can write it to Files.
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
