/// One piece of rig equipment.
///
/// Mirrors INDIMCP-server's `Component` (`rig_store.py`). `role` and `id` are the only required
/// fields; the rest are meaningful only for some roles (e.g. a `telescope` has `apertureMm`/
/// `focalLengthMm` but no `device`; a `camera` has `device` plus pixel geometry). `id` is a
/// stable handle for this specific component within the rig (a serial number, or any operator-
/// chosen label) — required, and unique within the rig — since a rig commonly has more than one
/// component sharing a role (e.g. two guide cameras).
public struct Component: Codable, Sendable, Hashable {
    public let role: Role
    public let id: String
    public let make: String?
    public let model: String?
    public let device: String?
    public let apertureMm: Double?
    public let focalLengthMm: Double?
    public let cooled: Bool?
    public let pixelsX: Int?
    public let pixelsY: Int?
    public let pixelSizeMicron: Double?
    public let bitDepth: Int?
    public let minPosition: Int?
    public let maxPosition: Int?
    /// Filter slot number to filter name, for a `filterWheel`-role component.
    public let slots: [Int: String]?

    public init(
        role: Role,
        id: String,
        make: String? = nil,
        model: String? = nil,
        device: String? = nil,
        apertureMm: Double? = nil,
        focalLengthMm: Double? = nil,
        cooled: Bool? = nil,
        pixelsX: Int? = nil,
        pixelsY: Int? = nil,
        pixelSizeMicron: Double? = nil,
        bitDepth: Int? = nil,
        minPosition: Int? = nil,
        maxPosition: Int? = nil,
        slots: [Int: String]? = nil
    ) {
        self.role = role
        self.id = id
        self.make = make
        self.model = model
        self.device = device
        self.apertureMm = apertureMm
        self.focalLengthMm = focalLengthMm
        self.cooled = cooled
        self.pixelsX = pixelsX
        self.pixelsY = pixelsY
        self.pixelSizeMicron = pixelSizeMicron
        self.bitDepth = bitDepth
        self.minPosition = minPosition
        self.maxPosition = maxPosition
        self.slots = slots
    }
}
