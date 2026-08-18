import INDIMCPKit
import SwiftUI

/// The symbol/color used to render an `Issue`'s `Severity` (`FramesView`'s per-frame `issues`
/// labels) — kept in the app target rather than `INDIMCPKit` itself, since the library doesn't
/// import SwiftUI/`Color`, matching `PropertyState.testAppIndicatorColor`'s own precedent.
extension Severity {
    var testAppSymbolName: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error, .fatal: return "xmark.octagon"
        }
    }

    var testAppTintColor: Color {
        switch self {
        case .info: return .secondary
        case .warning: return .orange
        case .error, .fatal: return .red
        }
    }
}
