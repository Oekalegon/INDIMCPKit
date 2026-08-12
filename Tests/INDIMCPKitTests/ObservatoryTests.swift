import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesObservatoryFromServerJSONShape() throws {
    let json = Data(
        #"{"id": "test-obs", "name": "Test Observatory", "latitudeDeg": 52.1, "longitudeDeg": 5.1, "elevationMeters": 10.0}"#
            .utf8
    )
    let observatory = try JSONDecoder().decode(Observatory.self, from: json)
    #expect(
        observatory
            == Observatory(id: "test-obs", name: "Test Observatory", latitudeDeg: 52.1, longitudeDeg: 5.1, elevationMeters: 10)
    )
}
