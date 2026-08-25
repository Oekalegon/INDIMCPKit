/// A rig-scoped handle for the `filterWheel`-role component of a saved rig.
///
/// Obtained via `INDIMCPClient.filterWheel(rigId:)`, not constructed directly. See `Mount`'s doc
/// comment for the connectivity-check behavior shared by every device-type handle.
public struct FilterWheel: DeviceHandle {
    /// The MCP client this device handle was obtained from.
    public let client: INDIMCPClient
    /// The id of the rig this device handle belongs to.
    public let rigId: String
    /// The role this device handle plays within its rig.
    public let role: Role = .filterWheel

    init(client: INDIMCPClient, rigId: String) {
        self.client = client
        self.rigId = rigId
    }

    /// Selects a filter by name, matching the rig's configured `filterWheel` slots map. See
    /// `INDIMCPClient.selectFilter`'s doc comment for the reconciliation-against-the-driver
    /// behavior this triggers server-side.
    public func selectFilter(_ filterName: String) async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .filterWheel, rigId: rigId)
        return try await client.selectFilter(rigId: rigId, filterName: filterName)
    }

    /// The name of the currently selected filter, per the rig's configured slot map — `nil` if
    /// undetermined (no `FILTER_SLOT` observed yet, the live slot isn't in the rig's `slots` map,
    /// the rig has no single `filterWheel`-role component, or the property read itself fails for
    /// any reason). Read-side counterpart to `selectFilter`.
    public func currentFilterName() async throws -> String? {
        let rig = try await client.getRig(id: rigId)
        guard let component = uniqueComponent(for: .filterWheel, in: rig), let device = component.device else {
            return nil
        }
        guard let properties = try? await client.getDeviceProperties(device: device) else {
            return nil
        }
        guard let slot = parseINDIInt(properties.properties["FILTER_SLOT"]?.elements["FILTER_SLOT_VALUE"]) else {
            return nil
        }
        return (component.slots ?? [:])[slot]
    }

    /// The rig's configured slot-number → filter-name map for this filter wheel — the "source of
    /// truth" independent of whatever the driver currently reports live. `.count` is the
    /// *configured* slot count. Empty if the rig has no single `filterWheel`-role component.
    public func filterNames() async throws -> [Int: String] {
        let rig = try await client.getRig(id: rigId)
        return uniqueComponent(for: .filterWheel, in: rig)?.slots ?? [:]
    }

    /// The filter wheel's live slot-number → filter-name map, read directly from the connected
    /// driver's `FILTER_NAME` property — independent of the rig's configured `slots` (which may
    /// not exist yet, e.g. before this filter wheel has ever been configured, or may disagree
    /// with the driver). Empty if the device hasn't reported `FILTER_NAME` yet, or the rig has no
    /// single `filterWheel`-role component.
    ///
    /// `.count` is the number of positions the connected filter wheel actually reports — the
    /// answer to "how many slots does this filter wheel have", independent of naming. Same
    /// primitive `syncFilterNames`/`adoptFilterNamesFromDriver` already use server-side to detect
    /// a slot-count mismatch.
    public func liveFilterNames() async throws -> [Int: String] {
        let rig = try await client.getRig(id: rigId)
        guard let device = uniqueComponent(for: .filterWheel, in: rig)?.device else {
            return [:]
        }
        guard let properties = try? await client.getDeviceProperties(device: device) else {
            return [:]
        }
        guard let elements = properties.properties["FILTER_NAME"]?.elements else {
            return [:]
        }
        let prefix = "FILTER_SLOT_NAME_"
        var slots: [Int: String] = [:]
        for (key, value) in elements {
            guard key.hasPrefix(prefix), let slot = Int(key.dropFirst(prefix.count)) else {
                continue
            }
            slots[slot] = value
        }
        return slots
    }

    /// Sets (or renames) filter position `slot`'s name in the rig's saved configuration, via
    /// `saveRig(overwrite: true)`. Does **not** push the change to the live driver — see
    /// `syncFilterNames()` for that, a deliberate, separate step; a live hardware write is never
    /// a side effect of a config change anywhere in this kit.
    ///
    /// - Returns: The filter wheel's full slot map after the change.
    /// - Throws: `DeviceControlError.noComponentForRole` if the rig has no `filterWheel`-role
    ///   component, or `DeviceControlError.ambiguousComponentForRole` if it has more than one —
    ///   this always mutates exactly one component's `slots`, never guesses which.
    public func setFilterName(slot: Int, name: String) async throws -> [Int: String] {
        let rig = try await client.getRig(id: rigId)
        let component = try resolveUniqueComponent(for: .filterWheel, in: rig, rigId: rigId)
        guard let index = rig.components.firstIndex(where: { $0.id == component.id }) else {
            throw DeviceControlError.noComponentForRole(role: .filterWheel, rigId: rigId)
        }
        var updatedSlots = rig.components[index].slots ?? [:]
        updatedSlots[slot] = name
        var updatedComponents = rig.components
        updatedComponents[index] = rig.components[index].withSlots(updatedSlots)
        let saved = try await client.saveRig(
            Rig(id: rig.id, name: rig.name, components: updatedComponents),
            overwrite: true
        )
        return saved.components.first(where: { $0.role == .filterWheel })?.slots ?? [:]
    }

    /// Pushes the rig's configured filter names to the driver's live `FILTER_NAME`, if they
    /// disagree. Thin wrapper dropping the redundant `rigId`/`role` from
    /// `INDIMCPClient.syncFilterNames`.
    public func syncFilterNames() async throws -> FilterSyncOutcome {
        try await client.ensureConnected(role: .filterWheel, rigId: rigId)
        return try await client.syncFilterNames(rigID: rigId, role: role.rawValue)
    }

    /// Copies the driver's live `FILTER_NAME` onto the rig, overwriting whatever filter slots the
    /// rig currently declares. Thin wrapper over `INDIMCPClient.adoptFilterNamesFromDriver`.
    public func adoptFilterNamesFromDriver() async throws -> FilterAdoptOutcome {
        try await client.ensureConnected(role: .filterWheel, rigId: rigId)
        return try await client.adoptFilterNamesFromDriver(rigID: rigId, role: role.rawValue)
    }
}

extension INDIMCPClient {
    /// A handle for rig `rigId`'s `filterWheel`-role component.
    public func filterWheel(rigId: String) -> FilterWheel {
        FilterWheel(client: self, rigId: rigId)
    }
}
