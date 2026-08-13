import INDIMCPKit
import SwiftUI

/// Renders an `ObservableDevice`'s current `properties` — shared across every device screen
/// (Mount/Camera/FilterWheel/Focuser) rather than duplicated per screen, since the rendering logic
/// doesn't depend on which role it's showing.
struct DevicePropertiesSection: View {
    let properties: [String: DeviceProperty]
    let isRefreshed: Bool
    let lastError: String?

    var body: some View {
        Section("Live Properties" + (isRefreshed ? "" : " (last known, not yet confirmed live)")) {
            if let lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if properties.isEmpty {
                Text("No properties reported yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(properties.keys.sorted(), id: \.self) { name in
                    if let property = properties[name] {
                        propertyRow(name: name, property: property)
                    }
                }
            }
        }
    }

    private func propertyRow(name: String, property: DeviceProperty) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let state = property.state {
                    Circle()
                        .fill(color(for: state))
                        .frame(width: 8, height: 8)
                        .help(state.rawValue)
                }
                Text(name)
                    .font(.subheadline.bold())
                if let type = property.type {
                    Text(type)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let state = property.state {
                    Text(state.rawValue)
                        .font(.caption)
                        .foregroundStyle(color(for: state))
                }
            }

            if property.elements.isEmpty {
                Text("(no elements)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(property.elements.sorted(by: { $0.key < $1.key }), id: \.key) { element in
                    HStack {
                        Text(element.key)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(element.value)
                            .font(.caption.monospaced())
                    }
                    .padding(.leading, 14)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func color(for state: PropertyState) -> Color {
        switch state {
        case .idle: return .gray
        case .ok: return .green
        case .busy: return .yellow
        case .alert: return .red
        case .other: return .secondary
        }
    }
}
