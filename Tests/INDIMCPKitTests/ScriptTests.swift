import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesScriptWithOpaqueSteps() throws {
    // Mirrors the real park.yaml shape: steps this kit deliberately doesn't statically model —
    // see Script.swift's doc comment — must still decode without throwing, as raw Value.
    let json = Data(
        #"""
        {
          "id": "park",
          "name": "Park the mount",
          "description": "Parks the rig's mount.",
          "pausable": false,
          "parameters": {},
          "steps": [
            {
              "step": "set_property",
              "role": "mount",
              "property": "TELESCOPE_PARK",
              "elements": { "PARK": "On" }
            },
            {
              "step": "wait_for",
              "condition": { "role": "mount", "property": "TELESCOPE_PARK", "operator": "equals", "value": "Ok" },
              "timeoutSeconds": 60
            }
          ]
        }
        """#.utf8
    )
    let script = try JSONDecoder().decode(Script.self, from: json)
    #expect(script.id == "park")
    #expect(script.pausable == false)
    #expect(script.parameters.isEmpty)
    #expect(script.steps.count == 2)
}

@Test func decodesParameterWithDefault() throws {
    let json = Data(
        #"{"ra": {"type": "number", "required": true, "default": null, "description": "RA in hours."}}"#.utf8
    )
    let parameters = try JSONDecoder().decode([String: Parameter].self, from: json)
    #expect(parameters["ra"]?.type == .number)
    #expect(parameters["ra"]?.required == true)
    #expect(parameters["ra"]?.default == nil)
}
