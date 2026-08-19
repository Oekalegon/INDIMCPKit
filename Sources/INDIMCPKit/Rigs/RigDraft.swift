/// A draft rig skeleton, pre-filled from currently connected INDI devices by `draftRig`.
///
/// Mirrors INDIMCP-server's `RigDraft` (`rig_store.py`). Never a finished rig: fields INDI can't
/// supply and any ambiguous role assignments are left for the operator to complete before saving
/// via `saveRig`.
public struct RigDraft: Codable, Sendable, Hashable {
    /// A discriminator identifying this payload as a rig draft.
    public let kind: String
    /// The components pre-filled from connected devices, possibly incomplete.
    public let components: [Component]
    /// Warnings about the draft, such as ambiguous role assignments or missing fields.
    public let notes: [String]

    /// Creates a new rig draft.
    public init(kind: String, components: [Component], notes: [String]) {
        self.kind = kind
        self.components = components
        self.notes = notes
    }
}
