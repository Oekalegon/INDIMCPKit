import MCP

/// One parameter a script declares, substitutable into its steps via `{{ name }}`.
///
/// Mirrors INDIMCP-server's `Parameter` (`script_store.py`). `default` is kept as the raw
/// `Value` rather than typed to `type`, since its actual Swift type depends on `type`'s runtime
/// value (a `Parameter` isn't generic) — decode it against `type` at the call site if needed.
public struct Parameter: Codable, Sendable, Hashable {
    public let type: ParameterType
    public let required: Bool
    public let `default`: Value?
    public let description: String?

    public init(
        type: ParameterType,
        required: Bool = false,
        default: Value? = nil,
        description: String? = nil
    ) {
        self.type = type
        self.required = required
        self.default = `default`
        self.description = description
    }
}
