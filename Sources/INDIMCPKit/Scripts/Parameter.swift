import MCP

/// One parameter a script declares, substitutable into its steps via `{{ name }}`.
///
/// Mirrors INDIMCP-server's `Parameter` (`script_store.py`). `default` is kept as the raw
/// `Value` rather than typed to `type`, since its actual Swift type depends on `type`'s runtime
/// value (a `Parameter` isn't generic) — decode it against `type` at the call site if needed.
public struct Parameter: Codable, Sendable, Hashable {
    /// The parameter's declared type.
    public let type: ParameterType
    /// Whether a value for this parameter must be supplied when running the script.
    public let required: Bool
    /// The value used when the parameter isn't supplied, as a raw `Value` typed by `type`.
    public let `default`: Value?
    /// A human-readable description of the parameter.
    public let description: String?

    /// Creates a new script parameter.
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
