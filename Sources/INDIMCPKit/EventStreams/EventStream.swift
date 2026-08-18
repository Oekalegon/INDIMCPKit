/// Which durable event-log stream (and matching subscribable resource family) an event belongs
/// to — `"messages"` for the INDI messaging layer (`indi://messages`), `"scripts"` for the
/// scripting layer (`indi://mcp-server/scripts`), `"connection"` for connection-lifecycle events
/// (`indi://mcp-server/connection`, INDIMCP-57).
///
/// Mirrors INDIMCP-server's `Stream` (`event_log.py`), a closed `Literal["messages", "scripts",
/// "connection"]` rather than an open string set like `Role`/`PropertyState` — unlike those, this
/// isn't a server-extensible vocabulary; it's fixed by which resource families the server
/// actually implements (see `docs/Design.md#event-streams`).
public enum EventStream: String, Codable, Sendable {
    case messages
    case scripts
    case connection
}
