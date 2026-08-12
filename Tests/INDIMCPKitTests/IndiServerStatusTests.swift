import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesIndiServerStatusFromServerJSONShape() throws {
    let json = Data(#"{"running": true, "port": 7624}"#.utf8)
    let status = try JSONDecoder().decode(IndiServerStatus.self, from: json)
    #expect(status == IndiServerStatus(running: true, port: 7624))
}
