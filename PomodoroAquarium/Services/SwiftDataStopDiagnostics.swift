#if DEBUG
import Foundation
import SwiftData
import OSLog

/// 停止調査専用。モデルをfetch/saveせず、Context/Containerを強参照しない。
/// 通知中にUIや永続モデルを変更しない。Releaseには含めない。
@MainActor
enum SwiftDataStopDiagnostics {
    private final class Entry {
        weak var context: ModelContext?
        weak var container: ModelContainer?
        let token: Int
        var roles: Set<String>
        init(_ context: ModelContext, token: Int, role: String) {
            self.context = context
            container = context.container
            self.token = token
            roles = [role]
        }
    }
    private static var entries: [ObjectIdentifier: Entry] = [:]
    private static var observers: [NSObjectProtocol] = []
    private static var nextToken = 0
    private static var lastCheckpoint = Date.distantPast
    private static var saveCount = 0
    static var logURL: URL {
        URL.cachesDirectory.appendingPathComponent("swiftdata-stop-debug.log")
    }

    static func register(_ context: ModelContext, role: String) {
        startIfNeeded()
        let id = ObjectIdentifier(context)
        if let entry = entries[id], entry.context === context {
            if entry.roles.insert(role).inserted { write("bind context=\(entry.token) role=\(role)") }
            return
        }
        nextToken += 1
        let entry = Entry(context, token: nextToken, role: role)
        entries[id] = entry
        write("register context=\(entry.token) address=\(id) container=\(ObjectIdentifier(context.container)) " +
              "role=\(role) autosave=\(context.autosaveEnabled) schema=\(context.container.schema.entities.map(\.name).sorted())")
    }

    static func record(_ event: String, context: ModelContext) {
        register(context, role: event)
        write("event=\(event) context=\(entries[ObjectIdentifier(context)]?.token ?? 0) changes=\(context.hasChanges)")
    }

    static func references(_ role: String, context: ModelContext, models: [any PersistentModel]) {
        register(context, role: role)
        let detached = models.filter { $0.modelContext == nil }.count
        let foreign = models.filter { $0.modelContext != nil && $0.modelContext !== context }.count
        let deleted = models.filter(\.isDeleted).count
        write("references role=\(role) context=\(entries[ObjectIdentifier(context)]?.token ?? 0) " +
              "count=\(models.count) detached=\(detached) foreign=\(foreign) deleted=\(deleted)")
    }

    /// 既存の1秒tickから30秒ごとに観測するだけ。新しいTimer/Taskは作らない。
    static func checkpoint(context: ModelContext, screen: String, player: Player?) {
        guard Date().timeIntervalSince(lastCheckpoint) >= 30 else { return }
        lastCheckpoint = Date()
        register(context, role: "MainTab")
        for (id, entry) in entries {
            if entry.context == nil {
                write("released context=\(entry.token) roles=\(entry.roles.sorted()) containerAlive=\(entry.container != nil)")
                entries.removeValue(forKey: id)
            } else if entry.container == nil {
                write("INVALID_LIFETIME context=\(entry.token) roles=\(entry.roles.sorted()) containerReleased=true")
            }
        }
        guard entries[ObjectIdentifier(context)]?.container != nil else { return }
        write("idle screen=\(screen) context=\(entries[ObjectIdentifier(context)]?.token ?? 0) " +
              "changes=\(context.hasChanges) inserted=\(types(context.insertedModelsArray)) " +
              "changed=\(types(context.changedModelsArray)) deleted=\(types(context.deletedModelsArray)) saves=\(saveCount)")
        if let player { references("MainTab.player", context: context, models: [player]) }
    }

    private static func startIfNeeded() {
        guard observers.isEmpty else { return }
        // 全Contextの通知を意図的に観測し、本番/Preview間の通知混在を区別する。
        for name in [ModelContext.willSave, ModelContext.didSave] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { note in
                guard Thread.isMainThread else {
                    Logger(subsystem: "PomodoroAquarium", category: "SwiftDataStop").error("save notification off main thread: \(note.name.rawValue, privacy: .public)")
                    return
                }
                MainActor.assumeIsolated { receive(note) }
            })
        }
        write("launch pid=\(ProcessInfo.processInfo.processIdentifier) os=\(ProcessInfo.processInfo.operatingSystemVersionString)")
    }

    private static func receive(_ note: Notification) {
        guard let context = note.object as? ModelContext else { write("notification=\(note.name) object=nonContext"); return }
        let entry = entries[ObjectIdentifier(context)]
        if note.name == ModelContext.willSave { saveCount += 1 }
        let keys = note.userInfo?.keys.map { String(describing: $0) }.sorted() ?? []
        write("notification=\(note.name.rawValue) context=\(entry?.token ?? 0) address=\(ObjectIdentifier(context)) " +
              "roles=\(entry?.roles.sorted() ?? []) containerAlive=\(entry?.container != nil) keys=\(keys)")
        // 未登録ContextやContainer解放後のContextへ追加アクセスしない。
        guard let entry, entry.container != nil else { return }
        if note.name == ModelContext.willSave {
            write("pending inserted=\(types(context.insertedModelsArray)) changed=\(types(context.changedModelsArray)) deleted=\(types(context.deletedModelsArray))")
            write("save-stack=\(Thread.callStackSymbols.dropFirst(8).prefix(24).joined(separator: " | "))")
        }
    }

    private static func types(_ models: [any PersistentModel]) -> String {
        Dictionary(grouping: models, by: { String(describing: type(of: $0)) })
            .map { "\($0.key):\($0.value.count)" }.sorted().joined(separator: ",")
    }

    private static func write(_ message: String) {
        let line = "[SwiftDataStop] \(Date().timeIntervalSince1970) \(message)\n"
        Logger(subsystem: "PomodoroAquarium", category: "SwiftDataStop").notice("\(line, privacy: .public)")
        guard let data = line.data(using: .utf8) else { return }
        // 調査ログのみ256KB以内。所持・記録・下書きには触れない。
        do {
            if !FileManager.default.fileExists(atPath: logURL.path) { try data.write(to: logURL); return }
            let handle = try FileHandle(forWritingTo: logURL)
            defer { try? handle.close() }
            if try handle.seekToEnd() > 256 * 1024 { try handle.truncate(atOffset: 0) }
            try handle.write(contentsOf: data)
        } catch { /* 診断の失敗は保存・表示へ影響させない */ }
    }
}
#endif
