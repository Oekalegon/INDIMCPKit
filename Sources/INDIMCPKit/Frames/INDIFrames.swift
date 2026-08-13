import MCP

extension INDIMCPClient {
    /// Lists captured frame metadata, most recently captured first, with optional filters.
    ///
    /// `transferred` is a tri-state: `nil` returns every frame, `true` only ones already
    /// confirmed received (`confirmFrameTransfer`), `false` only ones still waiting to be
    /// retrieved — useful for checking what's left to download before calling
    /// `purgeTransferredFrames`.
    public func listFrames(
        runId: String? = nil,
        device: String? = nil,
        since: String? = nil,
        transferred: Bool? = nil
    ) async throws -> [FrameMetadataResponse] {
        var arguments: [String: Value] = [:]
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
        return try await callToolList("list_frames", arguments: arguments, decoding: FrameMetadataResponse.self)
    }

    /// Returns the metadata for a single captured frame identified by `frameId`.
    public func getFrameMetadata(frameId: String) async throws -> FrameMetadataResponse {
        try await callTool(
            "get_frame_metadata",
            arguments: ["frame_id": .string(frameId)],
            decoding: FrameMetadataResponse.self
        )
    }

    /// Confirms the caller has safely saved a copy of `frameId` — call this only after actually
    /// verifying the bytes `downloadFrame` fetched were received intact. This is what makes a
    /// frame eligible for `deleteFrame`/`purgeTransferredFrames` later, so confirming a transfer
    /// that didn't really complete risks the server losing the only copy of that frame.
    public func confirmFrameTransfer(frameId: String) async throws -> FrameMetadata {
        try await callTool(
            "confirm_frame_transfer",
            arguments: ["frame_id": .string(frameId)],
            decoding: FrameMetadata.self
        )
    }

    /// Deletes a single captured frame's file and metadata, returning its metadata as it was.
    ///
    /// Refuses to delete a frame that hasn't been confirmed transferred (`confirmFrameTransfer`)
    /// unless `requireTransferred` is explicitly set to `false` — this is destructive on the
    /// actual science data the server exists to capture, so it's safe by default rather than
    /// trusting every caller to check first.
    public func deleteFrame(frameId: String, requireTransferred: Bool = true) async throws -> FrameMetadata {
        try await callTool(
            "delete_frame",
            arguments: ["frame_id": .string(frameId), "require_transferred": .bool(requireTransferred)],
            decoding: FrameMetadata.self
        )
    }

    /// Bulk-deletes every already-transferred frame captured more than `olderThanDays` ago,
    /// returning the metadata of every frame actually deleted.
    ///
    /// Never runs automatically — this is the only way old frames get cleaned up. Only ever
    /// considers frames already confirmed transferred (`confirmFrameTransfer`), regardless of
    /// age; a frame not yet confirmed received is never deleted by this call.
    public func purgeTransferredFrames(olderThanDays: Double) async throws -> [FrameMetadata] {
        try await callToolList(
            "purge_transferred_frames",
            arguments: ["older_than_days": .double(olderThanDays)],
            decoding: FrameMetadata.self
        )
    }
}
