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
    #expect(observatory.horizonProfile == nil)
}

@Test func decodesObservatoryWithHorizonProfileFromServerJSONShape() throws {
    let json = Data(
        #"""
        {
            "id": "test-obs", "name": "Test Observatory",
            "latitudeDeg": 52.1, "longitudeDeg": 5.1, "elevationMeters": 10.0,
            "horizonProfile": [
                {"azimuthDeg": 0, "altitudeDeg": 5.2},
                {"azimuthDeg": 90, "altitudeDeg": 12.9},
                {"azimuthDeg": 180, "altitudeDeg": 8.6},
                {"azimuthDeg": 270, "altitudeDeg": 3.7}
            ]
        }
        """#.utf8
    )
    let observatory = try JSONDecoder().decode(Observatory.self, from: json)
    #expect(
        observatory
            == Observatory(
                id: "test-obs",
                name: "Test Observatory",
                latitudeDeg: 52.1,
                longitudeDeg: 5.1,
                elevationMeters: 10,
                horizonProfile: [
                    HorizonPoint(azimuthDeg: 0, altitudeDeg: 5.2),
                    HorizonPoint(azimuthDeg: 90, altitudeDeg: 12.9),
                    HorizonPoint(azimuthDeg: 180, altitudeDeg: 8.6),
                    HorizonPoint(azimuthDeg: 270, altitudeDeg: 3.7),
                ]
            )
    )
}

@Test func encodesObservatoryOmittingNilHorizonProfile() throws {
    let observatory = Observatory(id: "test-obs", name: "Test Observatory", latitudeDeg: 52.1, longitudeDeg: 5.1)
    let json = try JSONEncoder().encode(observatory)
    let object = try JSONSerialization.jsonObject(with: json) as? [String: Any]
    #expect(object?["horizonProfile"] == nil)
}
