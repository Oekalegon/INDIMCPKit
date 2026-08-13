import MCP

extension INDIMCPClient {
    /// Connects to the INDI server and starts streaming its property/message events.
    public func startINDIMessaging(
        host: String = "localhost",
        port: Int = defaultINDIServerPort
    ) async throws -> MessagingStatus {
        try await callTool(
            "start_indi_messaging",
            arguments: ["host": .string(host), "port": .int(port)],
            decoding: MessagingStatus.self
        )
    }

    /// Disconnects from the INDI server and stops streaming its events.
    public func stopINDIMessaging() async throws -> MessagingStatus {
        try await callTool("stop_indi_messaging", decoding: MessagingStatus.self)
    }

    /// Reports whether the INDI messaging stream is running, and its host/port.
    public func getINDIMessagingStatus() async throws -> MessagingStatus {
        try await callTool("get_indi_messaging_status", decoding: MessagingStatus.self)
    }

    /// Lists the most recently seen INDI events, newest first, optionally filtered to one device.
    public func listINDIMessages(device: String? = nil, limit: Int = 50) async throws -> [IndiEvent] {
        var arguments: [String: Value] = ["limit": .int(limit)]
        if let device {
            arguments["device"] = .string(device)
        }
        return try await callToolList("list_indi_messages", arguments: arguments, decoding: IndiEvent.self)
    }

    /// Queries the INDI server for the live state of every property on `device`.
    ///
    /// Queries `indiserver` directly (`getProperties`) rather than returning whatever was last
    /// cached, so the result reflects the device's actual state at call time when possible —
    /// check the returned `refreshed` flag, which is `false` if the driver didn't respond in
    /// time and `properties` fell back to a previously-cached reading. The MCP tool itself
    /// exposes no timeout parameter (only `device`), even though the server's own internal
    /// implementation supports one.
    public func getDeviceProperties(device: String) async throws -> DeviceProperties {
        try await callTool(
            "get_device_properties",
            arguments: ["device": .string(device)],
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
            "send_indi_property",
            arguments: [
                "device": .string(device),
                "name": .string(name),
                "elements": .object(elements.mapValues(Value.string)),
            ],
            decoding: IndiEvent.self
        )
    }
}
