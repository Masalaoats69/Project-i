import AppIntents
import Foundation

enum BlockLiveActivityAction: Sendable {
    case setPaused(blockID: UUID, dateKey: String, paused: Bool)
    case end(blockID: UUID, dateKey: String)
}

@MainActor
final class BlockLiveActivityActionBridge {
    static let shared = BlockLiveActivityActionBridge()

    private var handler: ((BlockLiveActivityAction) -> Void)?

    private init() {}

    func register(_ handler: @escaping (BlockLiveActivityAction) -> Void) {
        self.handler = handler
    }

    func perform(_ action: BlockLiveActivityAction) {
        handler?(action)
    }
}

struct SetBlockPausedIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or resume focus block"

    @Parameter(title: "Block ID")
    var blockID: String

    @Parameter(title: "Date")
    var dateKey: String

    @Parameter(title: "Paused")
    var paused: Bool

    init() {}

    init(blockID: UUID, dateKey: String, paused: Bool) {
        self.blockID = blockID.uuidString
        self.dateKey = dateKey
        self.paused = paused
    }

    func perform() async throws -> some IntentResult {
        guard let blockID = UUID(uuidString: blockID) else { return .result() }
        await BlockLiveActivityActionBridge.shared.perform(
            .setPaused(blockID: blockID, dateKey: dateKey, paused: paused)
        )
        return .result()
    }
}

struct EndBlockIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End focus block"

    @Parameter(title: "Block ID")
    var blockID: String

    @Parameter(title: "Date")
    var dateKey: String

    init() {}

    init(blockID: UUID, dateKey: String) {
        self.blockID = blockID.uuidString
        self.dateKey = dateKey
    }

    func perform() async throws -> some IntentResult {
        guard let blockID = UUID(uuidString: blockID) else { return .result() }
        await BlockLiveActivityActionBridge.shared.perform(
            .end(blockID: blockID, dateKey: dateKey)
        )
        return .result()
    }
}
