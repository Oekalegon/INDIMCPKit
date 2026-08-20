import INDIMCPKit
import Foundation

let client = INDIMCPClient(endpoint: URL(string: "http://telescope.local:8000/mcp")!)
try await client.connect()

try await client.startINDIMessaging()

let camera = client.camera(rigId: "my-rig")
