import Testing

@testable import INDIMCPKit

/// Exercises `Camera`'s pure property-parsing helpers offline, against hand-built
/// `DeviceProperties` fixtures — no live server needed.
///
/// This is exactly the coverage that was missing when `isCoolerOn()`'s `properties[...] == "On"`
/// pattern silently returned `false` instead of `nil` for a device with no `CCD_COOLER` observed
/// at all: the only test that looked like it covered that case actually exercised a different,
/// unrelated code path (an unknown device), and the bug shipped undetected until live
/// verification happened to catch it. These tests construct the exact "device known, property
/// absent" fixture that neither offline nor live coverage previously reached.
@Suite("Camera property parsing")
struct CameraPropertyParsingTests {
    @Test("coolerOn reads COOLER_ON as true/false when CCD_COOLER is present")
    func coolerOnReadsKnownState() {
        #expect(Camera.coolerOn(from: properties(["CCD_COOLER": ["COOLER_ON": "On"]])) == true)
        #expect(Camera.coolerOn(from: properties(["CCD_COOLER": ["COOLER_ON": "Off"]])) == false)
    }

    @Test("coolerOn reports nil, not false, when CCD_COOLER has never been observed")
    func coolerOnNilWhenNeverObserved() {
        // The regression case: CCD_COOLER is absent entirely (not "Off", not empty elements —
        // absent), on a device whose properties snapshot otherwise decoded fine. Before the fix,
        // this returned .some(false) instead of nil.
        #expect(Camera.coolerOn(from: properties([:])) == nil)
    }

    @Test("coolerOn reports nil when CCD_COOLER is present but missing COOLER_ON specifically")
    func coolerOnNilWhenElementMissing() {
        #expect(Camera.coolerOn(from: properties(["CCD_COOLER": ["COOLER_OFF": "Off"]])) == nil)
    }

    @Test("doubleElement reads a present element and reports nil for an absent one")
    func doubleElementReadsOrReportsNil() {
        #expect(
            Camera.doubleElement(
                "CCD_TEMPERATURE", "CCD_TEMPERATURE_VALUE",
                from: properties(["CCD_TEMPERATURE": ["CCD_TEMPERATURE_VALUE": "-9.5"]])
            ) == -9.5
        )
        #expect(Camera.doubleElement("CCD_TEMPERATURE", "CCD_TEMPERATURE_VALUE", from: properties([:])) == nil)
    }

    @Test("intElement tolerates INDI's float-formatted whole numbers")
    func intElementParsesFloatFormattedNumbers() {
        #expect(Camera.intElement("CCD_INFO", "CCD_BITSPERPIXEL", from: properties(["CCD_INFO": ["CCD_BITSPERPIXEL": "16.0"]])) == 16)
        #expect(Camera.intElement("CCD_INFO", "CCD_BITSPERPIXEL", from: properties([:])) == nil)
    }

    @Test("binning reads both elements together, or reports nil if either is missing")
    func binningReadsBothElementsOrNil() {
        let both = properties(["CCD_BINNING": ["HOR_BIN": "2", "VER_BIN": "2"]])
        let result = Camera.binning(from: both)
        #expect(result?.x == 2)
        #expect(result?.y == 2)

        let onlyOne = properties(["CCD_BINNING": ["HOR_BIN": "2"]])
        #expect(Camera.binning(from: onlyOne) == nil)
    }

    @Test("frame reads all four elements together, or reports nil if any is missing")
    func frameReadsAllElementsOrNil() {
        let all = properties(["CCD_FRAME": ["X": "0", "Y": "0", "WIDTH": "4096.0", "HEIGHT": "4096.0"]])
        let result = Camera.frame(from: all)
        #expect(result?.x == 0)
        #expect(result?.y == 0)
        #expect(result?.width == 4096)
        #expect(result?.height == 4096)

        let missingHeight = properties(["CCD_FRAME": ["X": "0", "Y": "0", "WIDTH": "4096"]])
        #expect(Camera.frame(from: missingHeight) == nil)
    }

    /// Builds a `DeviceProperties` fixture from a plain `[propertyName: [elementName: value]]`
    /// map, defaulting `type`/`state` to `nil` and `refreshed` to `true` — neither this file's
    /// tests nor `Camera`'s parsers care about those fields.
    private func properties(_ elements: [String: [String: String]]) -> DeviceProperties {
        DeviceProperties(
            properties: elements.mapValues { DeviceProperty(type: nil, state: nil, elements: $0) },
            refreshed: true
        )
    }
}
