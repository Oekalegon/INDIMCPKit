/// One piece of rig equipment.
///
/// Mirrors INDIMCP-server's `Component` (`rig_store.py`). `role` and `id` are the only required
/// fields; the rest are meaningful only for some roles (e.g. a `telescope` has `apertureMm`/
/// `focalLengthMm` but no `device`; a `camera` has `device` plus pixel geometry). `id` is a
/// stable handle for this specific component within the rig (a serial number, or any operator-
/// chosen label) — required, and unique within the rig — since a rig commonly has more than one
/// component sharing a role (e.g. two guide cameras).
public struct Component: Codable, Sendable, Hashable {
    /// The role this component fills within the rig.
    public let role: Role
    /// A stable handle for this component within the rig, unique among the rig's components.
    public let id: String
    /// The manufacturer name, if known.
    public let make: String?
    /// The model name, if known.
    public let model: String?
    /// The INDI device name driving this component, if resolved.
    public let device: String?
    /// The optical aperture in millimeters, for a `telescope`-role component.
    public let apertureMm: Double?
    /// The optical focal length in millimeters, for a `telescope`-role component.
    public let focalLengthMm: Double?
    /// Whether the component has active cooling, for a `camera`-role component.
    public let cooled: Bool?
    /// The sensor width in pixels, for a `camera`-role component.
    public let pixelsX: Int?
    /// The sensor height in pixels, for a `camera`-role component.
    public let pixelsY: Int?
    /// The pixel size in microns, for a `camera`-role component.
    public let pixelSizeMicron: Double?
    /// The sensor's analog-to-digital bit depth, for a `camera`-role component.
    public let bitDepth: Int?
    /// The minimum focuser position, for a `focuser`-role component.
    public let minPosition: Int?
    /// The maximum focuser position, for a `focuser`-role component.
    public let maxPosition: Int?
    /// Filter slot number to filter name, for a `filterWheel`-role component.
    public let slots: [Int: String]?

    /// Creates a new rig component.
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
