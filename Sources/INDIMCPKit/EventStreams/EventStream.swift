/// Which durable event-log stream (and matching subscribable resource family) an event belongs
/// to — `"messages"` for the INDI messaging layer (`indi://messages`), `"scripts"` for the
/// scripting layer (`indi://scripts`).
///
/// Mirrors INDIMCP-server's `Stream` (`event_log.py`), a closed `Literal["messages", "scripts"]`
/// rather than an open string set like `Role`/`PropertyState` — unlike those, this isn't a
/// server-extensible vocabulary; it's fixed by which two resource families the server actually
/// implements (see `docs/Design.md#event-streams`).
public enum EventStream: String, Codable, Sendable {
    case messages
    case scripts
}
