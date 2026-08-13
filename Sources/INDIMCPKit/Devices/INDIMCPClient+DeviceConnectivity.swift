extension INDIMCPClient {
    /// Whether rig `rigId` has at least one currently-connected component declaring `role` —
    /// the same connectivity check `Mount`/`Camera`/`FilterWheel`/`Focuser` run internally before
    /// issuing a command (see `ensureConnected`), exposed as its own call for UI that wants to
    /// reflect (and gate on) connection state up front, rather than only discovering it from a
    /// failed command.
    ///
    /// Same caveats as `ensureConnected`: a TOCTOU-prone snapshot, not cached, and requires INDI
    /// messaging to already be running server-side or this throws `INDIMCPClientError` rather
    /// than returning `false`.
    public func isDeviceConnected(role: Role, rigId: String) async throws -> Bool {
        try await !roleConnectivity(role: role, rigId: rigId).connectedComponentIds.isEmpty
    }

    /// Best-effort check that rig `rigId` has at least one currently-connected component
    /// declaring `role`, before `Mount`/`Camera`/`FilterWheel`/`Focuser` issue a command for it.
    ///
    /// Not a guarantee — this is a TOCTOU-prone early check (the device could disconnect between
    /// this call and the actual command reaching the server), and it can't distinguish "exactly
    /// one connected" from "more than one connected" the way the server's own role resolution
    /// does for e.g. `syncFilterNames` — it only rules out the common case of issuing a command
    /// for a role with nothing connected at all, turning that into a clear, immediate
    /// `DeviceControlError` instead of a script run that starts only to fail on its first step.
    ///
    /// Costs two extra round trips (`getRig` + `checkRig`) per call — deliberately not cached,
    /// since a rig's connection state can change between calls and a stale "yes, connected"
    /// answer would be worse than the extra latency.
    ///
    /// Can throw `INDIMCPClientError`, not just `DeviceControlError`: `checkRig` itself requires
    /// INDI messaging to be running server-side (it calls `indi_messaging.list_devices()`
    /// internally), so if messaging hasn't been started (`startINDIMessaging()`), this call fails
    /// with `INDIMCPClientError.toolCallFailed` before it ever gets to report on connectivity at
    /// all — confirmed against the real server. A caller catching only `DeviceControlError`
    /// around a `Mount`/`Camera`/`FilterWheel`/`Focuser` call would miss this case.
    func ensureConnected(role: Role, rigId: String) async throws {
        let connectivity = try await roleConnectivity(role: role, rigId: rigId)
        guard !connectivity.componentIds.isEmpty else {
            throw DeviceControlError.noComponentForRole(role: role, rigId: rigId)
        }
        guard !connectivity.connectedComponentIds.isEmpty else {
            throw DeviceControlError.deviceNotConnected(role: role, rigId: rigId)
        }
    }

    private struct RoleConnectivity {
        let componentIds: [String]
        let connectedComponentIds: [String]
    }

    private func roleConnectivity(role: Role, rigId: String) async throws -> RoleConnectivity {
        let rig = try await getRig(id: rigId)
        let componentIds = rig.components.filter { $0.role == role }.map(\.id)
        guard !componentIds.isEmpty else {
            return RoleConnectivity(componentIds: [], connectedComponentIds: [])
        }

        let check = try await checkRig(id: rigId)
        let connectedComponentIds = componentIds.filter { check.present.contains($0) }
        return RoleConnectivity(componentIds: componentIds, connectedComponentIds: connectedComponentIds)
    }
}
