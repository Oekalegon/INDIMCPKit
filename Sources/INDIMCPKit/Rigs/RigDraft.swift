/// A draft rig skeleton, pre-filled from currently connected INDI devices by `draftRig`.
///
/// Mirrors INDIMCP-server's `RigDraft` (`rig_store.py`). Never a finished rig: fields INDI can't
/// supply and any ambiguous role assignments are left for the operator to complete before saving
/// via `saveRig`.
public struct RigDraft: Codable, Sendable, Hashable {
    public let kind: String
    public let components: [Component]
    public let notes: [String]

    public init(kind: String, components: [Component], notes: [String]) {
        self.kind = kind
        self.components = components
        self.notes = notes
    }
}
