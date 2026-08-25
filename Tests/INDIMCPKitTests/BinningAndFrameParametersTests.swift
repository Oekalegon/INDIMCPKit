import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `INDIMCPClient.binningAndFrameParameters` offline — the parameter-building helper
/// shared by `captureFrame` and all four capture-sequence wrappers (`captureDarkSequence`/
/// `captureBiasSequence`/`captureFlatSequence`/`captureLightSequence`).
///
/// Extracted (IMCPKIT-62 review) after the same six-parameter block was copy-pasted across five
/// methods in two files — this is the test that copy-paste drift would have made cheap to skip
/// without a shared, directly-testable helper.
@Suite("binningAndFrameParameters")
struct BinningAndFrameParametersTests {
    @Test("binningX/binningY are always sent, matching their given values")
    func binningAlwaysSent() {
        let client = INDIMCPClient(endpoint: URL(string: "http://localhost:8123/mcp")!)
        let parameters = client.binningAndFrameParameters(
            binningX: 2, binningY: 3, frameX: nil, frameY: nil, frameWidth: nil, frameHeight: nil
        )
        #expect(parameters["binningX"] == .int(2))
        #expect(parameters["binningY"] == .int(3))
    }

    @Test("frame elements are omitted entirely when nil, leaving the full sensor in effect")
    func frameOmittedWhenNil() {
        let client = INDIMCPClient(endpoint: URL(string: "http://localhost:8123/mcp")!)
        let parameters = client.binningAndFrameParameters(
            binningX: 1, binningY: 1, frameX: nil, frameY: nil, frameWidth: nil, frameHeight: nil
        )
        #expect(parameters["frameX"] == nil)
        #expect(parameters["frameY"] == nil)
        #expect(parameters["frameWidth"] == nil)
        #expect(parameters["frameHeight"] == nil)
    }

    @Test("each frame element is sent under its own key, with no value swapped between them")
    func frameElementsSentUnderOwnKeys() {
        let client = INDIMCPClient(endpoint: URL(string: "http://localhost:8123/mcp")!)
        let parameters = client.binningAndFrameParameters(
            binningX: 1, binningY: 1, frameX: 10, frameY: 20, frameWidth: 100, frameHeight: 200
        )
        #expect(parameters["frameX"] == .int(10))
        #expect(parameters["frameY"] == .int(20))
        #expect(parameters["frameWidth"] == .int(100))
        #expect(parameters["frameHeight"] == .int(200))
    }
}
