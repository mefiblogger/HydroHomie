import SwiftUI

/// The three preset amounts plus a custom-amount button.
struct QuickAddRow: View {
    var unit: VolumeUnit
    var onAdd: (Double) -> Void
    var onCustom: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ForEach(unit.presetAmountsML, id: \.self) { amount in
                    Button {
                        onAdd(amount)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.caption.weight(.bold))
                            Text(unit.format(millilitres: amount))
                                .font(.callout.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                }
            }

            Button {
                onCustom()
            } label: {
                Label("Custom amount", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 14))
        }
    }
}
