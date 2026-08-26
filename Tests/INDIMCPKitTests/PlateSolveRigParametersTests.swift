import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `INDIMCPClient.plateSolveRigParameters` offline — `runPlateSolveRig`'s
/// parameter-building helper, split out so this conditional-inclusion logic is covered without a
/// live server, the same way `BinningAndFrameParametersTests` covers `binningAndFrameParameters`.
@Suite("plateSolveRigParameters")
struct PlateSolveRigParametersTests {
    private func makeClient() -> INDIMCPClient {
        INDIMCPClient(endpoint: URL(string: "http://localhost:8123/mcp")!)
    }

    @Test("exposureSeconds and toleranceArcsec are omitted when nil")
    func optionalParametersOmittedWhenNil() {
        let parameters = makeClient().plateSolveRigParameters(
            exposureSeconds: nil,
            syncMount: true,
            toleranceArcsec: nil,
            maxAttempts: 3,
            timeoutSeconds: 60,
            binningX: 1, binningY: 1,
            frameX: nil, frameY: nil, frameWidth: nil, frameHeight: nil
        )
        #expect(parameters["exposureSeconds"] == nil)
        #expect(parameters["toleranceArcsec"] == nil)
    }

    @Test("exposureSeconds and toleranceArcsec are sent under their own keys when given")
    func optionalParametersSentWhenGiven() {
        let parameters = makeClient().plateSolveRigParameters(
            exposureSeconds: 5,
            syncMount: true,
            toleranceArcsec: 30,
            maxAttempts: 3,
            timeoutSeconds: 60,
            binningX: 1, binningY: 1,
            frameX: nil, frameY: nil, frameWidth: nil, frameHeight: nil
        )
        #expect(parameters["exposureSeconds"] == .double(5))
        #expect(parameters["toleranceArcsec"] == .double(30))
    }

    @Test("syncMount/maxAttempts/timeoutSeconds are always sent, matching their given values")
    func alwaysSentParametersMatchGivenValues() {
        let parameters = makeClient().plateSolveRigParameters(
            exposureSeconds: nil,
            syncMount: false,
            toleranceArcsec: nil,
            maxAttempts: 7,
            timeoutSeconds: 12.5,
            binningX: 1, binningY: 1,
            frameX: nil, frameY: nil, frameWidth: nil, frameHeight: nil
        )
        #expect(parameters["syncMount"] == .bool(false))
        #expect(parameters["maxAttempts"] == .int(7))
        #expect(parameters["timeoutSeconds"] == .double(12.5))
    }

    @Test("binning/frame parameters are merged in, matching binningAndFrameParameters' own rules")
    func binningAndFrameParametersAreMerged() {
        let parameters = makeClient().plateSolveRigParameters(
            exposureSeconds: 5,
            syncMount: true,
            toleranceArcsec: nil,
            maxAttempts: 3,
            timeoutSeconds: 60,
            binningX: 2, binningY: 3,
            frameX: 10, frameY: 20, frameWidth: 100, frameHeight: 200
        )
        #expect(parameters["binningX"] == .int(2))
        #expect(parameters["binningY"] == .int(3))
        #expect(parameters["frameX"] == .int(10))
        #expect(parameters["frameY"] == .int(20))
        #expect(parameters["frameWidth"] == .int(100))
        #expect(parameters["frameHeight"] == .int(200))
    }
}
