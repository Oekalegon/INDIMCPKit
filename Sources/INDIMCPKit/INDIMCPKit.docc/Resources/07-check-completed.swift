import INDIMCPKit
import Foundation

let client = INDIMCPClient(endpoint: URL(string: "http://telescope.local:8000/mcp")!)
try await client.connect()

try await client.startINDIMessaging()

let camera = client.camera(rigId: "my-rig")

let coolStarted = try await camera.coolCamera(targetTempC: -10)
try await client.waitForTerminalStatus(runId: coolStarted.runId)

let coolerOn = try await camera.isCoolerOn()
print(coolerOn == true ? "Cooler is on" : "Cooler state unknown or off")

let captureStarted = try await camera.captureFrame(
    exposureSeconds: 30,
    frameType: .light,
    gain: 120,
    offset: 30
)
let captureStatus = try await client.waitForTerminalStatus(runId: captureStarted.runId)

guard case .completed(let completed) = captureStatus else {
    // Handle `.failed`, `.cancelled`, or another non-completed `ScriptRunStatus` here.
    fatalError("Capture did not complete: \(captureStatus)")
}
print("Captured \(completed.result.framesCaptured) frame(s)")
