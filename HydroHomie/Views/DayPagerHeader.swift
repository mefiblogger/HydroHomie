// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The day being viewed, with a step either side. Tapping the date returns to today.
///
/// The forward arrow is hidden rather than removed on the current day, so the date
/// stays centred instead of shifting as you page.
struct DayPagerHeader: View {
    @Binding var day: Date

    private let calendar = Calendar.current

    private var isToday: Bool { calendar.isDateInToday(day) }

    private var label: String {
        // "Wed, 16 Sept"
        day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    var body: some View {
        HStack(spacing: 10) {
            arrow("chevron.left", label: "Previous day") { step(-1) }

            rule
            Button {
                guard !isToday else { return }
                withAnimation(.easeInOut(duration: 0.2)) { day = Date() }
            } label: {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.identity)
                    .fixedSize()
            }
            .buttonStyle(.plain)
            .disabled(isToday)
            .accessibilityHint(isToday ? "" : "Returns to today")
            rule

            arrow("chevron.right", label: "Next day") { step(1) }
                // Nothing to see beyond today, but the space is kept so the date
                // does not jump sideways when paging.
                .opacity(isToday ? 0 : 1)
                .disabled(isToday)
                .accessibilityHidden(isToday)
        }
    }

    private var rule: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(height: 1)
    }

    private func arrow(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func step(_ days: Int) {
        guard let moved = calendar.date(byAdding: .day, value: days, to: day) else { return }
        // Never past today.
        guard moved <= Date() || calendar.isDateInToday(moved) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { day = moved }
    }
}

#Preview {
    VStack(spacing: 30) {
        DayPagerHeader(day: .constant(Date()))
        DayPagerHeader(day: .constant(Calendar.current.date(byAdding: .day, value: -3, to: Date())!))
    }
    .padding()
}
