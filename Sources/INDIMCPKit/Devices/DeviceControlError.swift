/// Errors surfaced by the device-type abstractions (`Mount`, `Camera`, `FilterWheel`, `Focuser`)
/// before a command even reaches the server.
public enum DeviceControlError: Error, Sendable {
    /// The rig has no component declaring `role` at all — the command could never succeed.
    case noComponentForRole(role: Role, rigId: String)

    /// The rig has one or more components declaring `role`, but none of them are currently
    /// connected (per `checkRig`). This is a best-effort, TOCTOU-prone check — the device could
    /// still disconnect between this check and the command actually reaching the server, and a
    /// component with no `device` configured at all is never reported as connected, whether or
    /// not that's actually a problem for this rig.
    case deviceNotConnected(role: Role, rigId: String)

    /// The rig has more than one component declaring `role`, and the operation needs to pick
    /// exactly one to read or mutate (e.g. `FilterWheel.setFilterName`) — thrown rather than
    /// silently acting on whichever component happened to come first.
    case ambiguousComponentForRole(role: Role, rigId: String)
}

extension DeviceControlError: CustomStringConvertible {
    /// A human-readable description of the error.
    public var description: String {
        switch self {
        case .noComponentForRole(let role, let rigId):
            return "Rig '\(rigId)' has no component with role '\(role)'"
        case .deviceNotConnected(let role, let rigId):
            return "Rig '\(rigId)' has no connected component with role '\(role)'"
        case .ambiguousComponentForRole(let role, let rigId):
            return "Rig '\(rigId)' has more than one component with role '\(role)'"
        }
    }
}
