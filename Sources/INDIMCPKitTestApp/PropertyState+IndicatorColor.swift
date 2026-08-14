import INDIMCPKit
import SwiftUI

/// The status-dot/label color used for a `PropertyState` across every screen that renders one
/// (`DevicePropertiesSection`, `MessageStreamView`) — kept in the app target rather than
/// `INDIMCPKit` itself, since the library doesn't import SwiftUI/`Color`.
extension PropertyState {
    var testAppIndicatorColor: Color {
        switch self {
        case .idle: return .gray
        case .ok: return .green
        case .busy: return .yellow
        case .alert: return .red
        case .other: return .secondary
        }
    }
}
