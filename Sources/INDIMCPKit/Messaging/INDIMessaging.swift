import MCP

extension INDIMCPClient {
    /// Connects to the INDI server and starts streaming its property/message events.
    public func startINDIMessaging(
        host: String = "localhost",
        port: Int = defaultINDIServerPort
    ) async throws -> MessagingStatus {
        try await callTool(
            "manage_indi_infra",
            arguments: [
                "component": .string("messaging"),
                "action": .string("start"),
                "host": .string(host),
                "port": .int(port),
            ],
            decoding: MessagingStatus.self
        )
    }

    /// Disconnects from the INDI server and stops streaming its events.
    public func stopINDIMessaging() async throws -> MessagingStatus {
        try await callTool(
            "manage_indi_infra",
            arguments: ["component": .string("messaging"), "action": .string("stop")],
            decoding: MessagingStatus.self
        )
    }

    /// Reports whether the INDI messaging stream is running, and its host/port.
    public func getINDIMessagingStatus() async throws -> MessagingStatus {
        try await callTool(
            "get_indi_status",
            arguments: ["component": .string("messaging")],
            decoding: MessagingStatus.self
        )
    }

    /// Queries the INDI server for the live state of every property on `device`.
    ///
    /// Queries `indiserver` directly (`getProperties`) rather than returning whatever was last
    /// cached, so the result reflects the device's actual state at call time when possible —
    /// check the returned `refreshed` flag, which is `false` if the driver didn't respond in
    /// time and `properties` fell back to a previously-cached reading. The `indi_property` tool
    /// itself exposes no timeout parameter (only `device`), even though the server's own internal
    /// implementation supports one.
    public func getDeviceProperties(device: String) async throws -> DeviceProperties {
        try await callTool(
            "indi_property",
            arguments: ["action": .string("get"), "device": .string(device)],
            decoding: DeviceProperties.self
        )
    }

    /// Sends a command to an INDI device, setting `elements` on its property `name`.
    ///
    /// This is a low-level, unguarded passthrough — it can set any property on any device,
    /// including ones that move hardware (e.g. a mount's coordinate vector), with no
    /// confirmation or state checks. Prefer a device-type abstraction (`Mount`, `Camera`, ...)
    /// once available; use this directly only when you specifically need to bypass them.
    public func sendINDIProperty(
        device: String,
        name: String,
        elements: [String: String]
    ) async throws -> IndiEvent {
        try await callTool(
            "indi_property",
            arguments: [
                "action": .string("set"),
                "device": .string(device),
                "name": .string(name),
                "elements": .object(elements.mapValues(Value.string)),
            ],
            decoding: IndiEvent.self
        )
    }
}
