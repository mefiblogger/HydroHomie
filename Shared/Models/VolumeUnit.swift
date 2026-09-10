import Foundation

/// Display unit for volumes. Everything is stored in millilitres internally and
/// converted only at the presentation layer, so switching units never mutates data.
enum VolumeUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case millilitres
    case fluidOunces

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .millilitres: "ml"
        case .fluidOunces: "fl oz"
        }
    }

    var displayName: String {
        switch self {
        case .millilitres: "Millilitres (ml)"
        case .fluidOunces: "Fluid ounces (fl oz)"
        }
    }

    /// US customary fluid ounce.
    static let millilitresPerFluidOunce = 29.5735295625

    func fromMillilitres(_ ml: Double) -> Double {
        switch self {
        case .millilitres: ml
        case .fluidOunces: ml / Self.millilitresPerFluidOunce
        }
    }

    func toMillilitres(_ value: Double) -> Double {
        switch self {
        case .millilitres: value
        case .fluidOunces: value * Self.millilitresPerFluidOunce
        }
    }

    /// Formats a millilitre amount in this unit, e.g. `750 ml` or `25.4 fl oz`.
    func format(millilitres ml: Double) -> String {
        let value = fromMillilitres(ml)
        switch self {
        case .millilitres:
            return "\(Int(value.rounded())) \(shortName)"
        case .fluidOunces:
            return String(format: "%.1f %@", value, shortName)
        }
    }

    /// The quick-add amounts offered on the Today screen, in millilitres.
    var presetAmountsML: [Double] {
        switch self {
        case .millilitres: [250, 500, 750]
        case .fluidOunces: [236.588, 473.176, 709.765]  // 8, 16, 24 fl oz
        }
    }
}
