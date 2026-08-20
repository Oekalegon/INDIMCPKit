import MCP

/// A single script definition, as declared in one `scripts/*.yaml` (or `user_scripts/*.yaml`)
/// file on the server.
///
/// Mirrors INDIMCP-server's `Script` (`script_store.py`, see `docs/ScriptSchema.md`). Per
/// `README.md`, INDIMCPKit deliberately does not statically model a script's `steps` — the step
/// schema is an open, recursive union (`set_property`, `wait_for`, `capture_frame`, `slew`,
/// nested `run_script`, `repeat`, `if`, ...) that's exactly the kind of site/script-specific
/// detail this kit stays generic about. `steps` is kept as raw `Value`; `id`/`name`/
/// `description`/`pausable`/`parameters` are stable across every script and typed normally.
public struct Script: Codable, Sendable, Hashable {
    /// The script's unique identifier.
    public let id: String
    /// The script's human-readable name.
    public let name: String
    /// A human-readable description of the script, if provided.
    public let description: String?
    /// Whether the script can be paused mid-run.
    public let pausable: Bool
    /// The script's declared parameters, keyed by name.
    public let parameters: [String: Parameter]
    /// The script's steps, kept as raw, untyped values (see this type's discussion above).
    public let steps: [Value]

    /// Creates a new script.
    public init(
        id: String,
        name: String,
        description: String? = nil,
        pausable: Bool,
        parameters: [String: Parameter] = [:],
        steps: [Value] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.pausable = pausable
        self.parameters = parameters
        self.steps = steps
    }
}
