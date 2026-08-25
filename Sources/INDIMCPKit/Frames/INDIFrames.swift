import MCP

extension INDIMCPClient {
    /// Lists captured frame metadata, most recently captured first, with optional filters.
    ///
    /// `transferred` is a tri-state: `nil` returns every frame, `true` only ones already
    /// confirmed received (`confirmFrameTransfer`), `false` only ones still waiting to be
    /// retrieved — useful for checking what's left to download before calling
    /// `purgeTransferredFrames`.
    ///
    /// Uses `callToolList`, not `callTool`: `frames`'s declared Python return type,
    /// `list[FrameMetadataResponse] | FrameMetadataResponse`, is a `Union` FastMCP wraps as
    /// `{"result": ...}` regardless of which branch actually runs — `action: "list"` is the
    /// list-shaped branch, needing `callToolList`'s `[Output]` unwrapping (IMCPKIT-61).
    public func listFrames(
        runId: String? = nil,
        device: String? = nil,
        since: String? = nil,
        transferred: Bool? = nil
    ) async throws -> [FrameMetadataResponse] {
        var arguments: [String: Value] = ["action": .string("list")]
        if let runId {
            arguments["run_id"] = .string(runId)
        }
        if let device {
            arguments["device"] = .string(device)
        }
        if let since {
            arguments["since"] = .string(since)
        }
        if let transferred {
            arguments["transferred"] = .bool(transferred)
        }
        return try await callToolList("frames", arguments: arguments, decoding: FrameMetadataResponse.self)
    }

    /// Returns the metadata for a single captured frame identified by `frameId`.
    ///
    /// Uses `callToolUnion`, not `callTool`: `action: "get"` is the object-shaped branch of
    /// `frames`'s declared `Union` return type — see `listFrames`'s doc comment (IMCPKIT-61).
    public func getFrameMetadata(frameId: String) async throws -> FrameMetadataResponse {
        try await callToolUnion(
            "frames",
            arguments: ["action": .string("get"), "frame_id": .string(frameId)],
            decoding: FrameMetadataResponse.self
        )
    }

    /// Confirms the caller has safely saved a copy of `frameId` — call this only after actually
    /// verifying the bytes `downloadFrame` fetched were received intact. This is what makes a
    /// frame eligible for `deleteFrame`/`purgeTransferredFrames` later, so confirming a transfer
    /// that didn't really complete risks the server losing the only copy of that frame.
    ///
    /// Uses `callToolUnion`, not `callTool`: `manage_frame`'s declared Python return type,
    /// `FrameMetadata | list[FrameMetadata]`, is also a `Union` FastMCP wraps — `action:
    /// "confirm_transfer"` is an object-shaped branch (IMCPKIT-61).
    public func confirmFrameTransfer(frameId: String) async throws -> FrameMetadata {
        try await callToolUnion(
            "manage_frame",
            arguments: ["action": .string("confirm_transfer"), "frame_id": .string(frameId)],
            decoding: FrameMetadata.self
        )
    }

    /// Deletes a single captured frame's file and metadata, returning its metadata as it was.
    ///
    /// Refuses to delete a frame that hasn't been confirmed transferred (`confirmFrameTransfer`)
    /// unless `requireTransferred` is explicitly set to `false` — this is destructive on the
    /// actual science data the server exists to capture, so it's safe by default rather than
    /// trusting every caller to check first.
    ///
    /// Uses `callToolUnion` — `action: "delete"` is another object-shaped branch of
    /// `manage_frame`'s `Union` return type; see `confirmFrameTransfer`'s doc comment
    /// (IMCPKIT-61).
    public func deleteFrame(frameId: String, requireTransferred: Bool = true) async throws -> FrameMetadata {
        try await callToolUnion(
            "manage_frame",
            arguments: [
                "action": .string("delete"),
                "frame_id": .string(frameId),
                "require_transferred": .bool(requireTransferred),
            ],
            decoding: FrameMetadata.self
        )
    }

    /// Bulk-deletes every already-transferred frame captured more than `olderThanDays` ago,
    /// returning the metadata of every frame actually deleted.
    ///
    /// Never runs automatically — this is the only way old frames get cleaned up. Only ever
    /// considers frames already confirmed transferred (`confirmFrameTransfer`), regardless of
    /// age; a frame not yet confirmed received is never deleted by this call.
    ///
    /// Uses `callToolList`, not `callToolUnion`: `action: "purge"` is `manage_frame`'s
    /// list-shaped branch, returning `list[FrameMetadata]` — see `confirmFrameTransfer`'s doc
    /// comment for why the tool as a whole needs unwrapping either way (IMCPKIT-61).
    public func purgeTransferredFrames(olderThanDays: Double) async throws -> [FrameMetadata] {
        try await callToolList(
            "manage_frame",
            arguments: ["action": .string("purge"), "older_than_days": .double(olderThanDays)],
            decoding: FrameMetadata.self
        )
    }

    /// Deletes every already-transferred frame, regardless of age — a convenience over
    /// `purgeTransferredFrames(olderThanDays:)` for "I've downloaded everything I need, clean up
    /// now" rather than an age-based sweep. Frames are **never** deleted automatically by the
    /// server on its own initiative (unlike the durable event log, which purges after a day) —
    /// this is the only way frames that have already been safely copied elsewhere stop taking up
    /// the INDI Device's limited storage.
    ///
    /// Only ever considers frames already confirmed transferred (`confirmFrameTransfer`); a frame
    /// not yet confirmed received is untouched, same as `purgeTransferredFrames`.
    public func deleteAllTransferredFrames() async throws -> [FrameMetadata] {
        try await purgeTransferredFrames(olderThanDays: 0)
    }

    /// Deletes **every** captured frame on the server, including ones never confirmed
    /// transferred — anything not already safely copied elsewhere is gone for good. There's no
    /// single server tool for this (only `purgeTransferredFrames`, which only ever touches
    /// already-transferred frames); this composes `listFrames` with a `deleteFrame(requireTransferred:
    /// false)` per frame.
    ///
    /// `acknowledgingPermanentDataLoss` has no default and isn't a mere formality — it exists so
    /// this can't be called by accident (a typo'd method name, a copy-pasted call site) the way
    /// `deleteFrame`'s `requireTransferred` default already protects the single-frame case.
    /// INDIMCPKit itself has no UI to prompt an operator before this runs; a caller with a user
    /// interface (e.g. `INDIMCPKitTestApp`) is responsible for getting *actual* human confirmation
    /// before ever passing `true` here — this parameter only proves the caller's code path
    /// deliberately chose to, not that a person actually agreed to it.
    ///
    /// Not atomic across frames: if a `deleteFrame` call partway through the list throws, this
    /// rethrows immediately — some frames may already be deleted and others not. Call `listFrames`
    /// again afterward to see what's actually left rather than assuming all-or-nothing.
    public func deleteAllFrames(acknowledgingPermanentDataLoss: Bool) async throws -> [FrameMetadata] {
        guard acknowledgingPermanentDataLoss else {
            throw INDIMCPClientError.allFramesDeletionNotAcknowledged
        }
        let frames = try await listFrames()
        var deleted: [FrameMetadata] = []
        for frame in frames {
            deleted.append(try await deleteFrame(frameId: frame.frameId, requireTransferred: false))
        }
        return deleted
    }
}
