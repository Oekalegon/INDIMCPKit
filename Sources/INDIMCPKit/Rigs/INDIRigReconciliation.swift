import MCP

extension INDIMCPClient {
    /// `rig_diagnostics(action, rig_id?, role?, direction?)`, shared by `checkRig`/
    /// `syncFilterNames`/`adoptFilterNamesFromDriver` below — replaces the old dedicated
    /// `check_rig`/`sync_filter_names`/`adopt_filter_names_from_driver` tools (INDIMCP-115).
    /// `suggestRig()` calls the same tool directly rather than through this helper, since its
    /// return type is a bare list (needs `callToolList`'s `{"result": [...]}` unwrapping) rather
    /// than a single decoded object.
    private func rigDiagnostics<Output: Decodable & Sendable>(
        action: String,
        rigId: String? = nil,
        role: String? = nil,
        direction: String? = nil,
        decoding type: Output.Type
    ) async throws -> Output {
        var arguments: [String: Value] = ["action": .string(action)]
        if let rigId {
            arguments["rig_id"] = .string(rigId)
        }
        if let role {
            arguments["role"] = .string(role)
        }
        if let direction {
            arguments["direction"] = .string(direction)
        }
        return try await callTool("rig_diagnostics", arguments: arguments, decoding: Output.self)
    }

    /// Proposes which configured rig is likely mounted, by matching connected INDI devices.
    ///
    /// Never auto-selects a rig; candidates are sorted best match first for the operator or
    /// client to choose from. Requires messaging to be running (`startINDIMessaging`).
    public func suggestRig() async throws -> [RigSuggestion] {
        try await callToolList(
            "rig_diagnostics",
            arguments: ["action": .string("suggest")],
            decoding: RigSuggestion.self
        )
    }

    /// Reports which of rig `id`'s devices aren't currently connected.
    ///
    /// A warning, not a hard failure — a rig might be intentionally used without one of its
    /// devices (e.g. imaging without a guide camera). Requires messaging to be running
    /// (`startINDIMessaging`).
    public func checkRig(id: String) async throws -> RigCheck {
        try await rigDiagnostics(action: "check", rigId: id, decoding: RigCheck.self)
    }

    /// Pre-fills a draft rig skeleton from currently connected INDI devices.
    ///
    /// Combines each device's driver family with whatever live properties it exposes into a
    /// starting point; never auto-finalizes a rig. Requires messaging to be running
    /// (`startINDIMessaging`).
    public func draftRig() async throws -> RigDraft {
        try await configurationTool(action: "draft", kind: "rig", decoding: RigDraft.self)
    }

    /// Pushes rig `id`'s configured filter names for `role` to the driver's live `FILTER_NAME`,
    /// if they disagree.
    ///
    /// A deliberate action only — never called automatically by anything else in this kit, since
    /// overwriting a live device's own configuration should always be something the caller
    /// explicitly asked for. See `adoptFilterNamesFromDriver` for the reverse direction. Throws
    /// if `role` isn't a connected `filterWheel`-like component with `slots` configured, or if
    /// the rig and driver declare a different number of filter slots.
    public func syncFilterNames(rigID: String, role: String) async throws -> FilterSyncOutcome {
        try await rigDiagnostics(
            action: "sync",
            rigId: rigID,
            role: role,
            direction: "to_driver",
            decoding: FilterSyncOutcome.self
        )
    }

    /// Copies the driver's live `FILTER_NAME` for `role` onto rig `id`, overwriting whatever
    /// filter `slots` the rig currently declares — the reverse direction from
    /// `syncFilterNames`.
    ///
    /// A deliberate action only, for when a rig and its driver disagree and the operator decides
    /// the driver is the source of truth this time. Throws if `role` isn't a connected
    /// `filterWheel`-like component, or if the driver declares no filter slots at all.
    public func adoptFilterNamesFromDriver(rigID: String, role: String) async throws -> FilterAdoptOutcome {
        try await rigDiagnostics(
            action: "sync",
            rigId: rigID,
            role: role,
            direction: "from_driver",
            decoding: FilterAdoptOutcome.self
        )
    }
}
