// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import HydroHomie

final class VolumeUnitTests: XCTestCase {

    func testMillilitresRoundTripIsIdentity() {
        let unit = VolumeUnit.millilitres
        XCTAssertEqual(unit.toMillilitres(unit.fromMillilitres(750)), 750, accuracy: 0.0001)
    }

    func testFluidOunceConversion() {
        let unit = VolumeUnit.fluidOunces
        XCTAssertEqual(unit.fromMillilitres(29.5735295625), 1, accuracy: 0.0001)
        XCTAssertEqual(unit.toMillilitres(8), 236.588, accuracy: 0.001)
    }

    func testFluidOunceRoundTripSurvivesUnitSwitching() {
        let unit = VolumeUnit.fluidOunces
        let original = 2000.0
        let roundTripped = unit.toMillilitres(unit.fromMillilitres(original))
        XCTAssertEqual(roundTripped, original, accuracy: 0.0001)
    }

    func testFormattingUsesWholeMillilitres() {
        XCTAssertEqual(VolumeUnit.millilitres.format(millilitres: 749.6), "750 ml")
    }

    func testFormattingUsesOneDecimalForOunces() {
        XCTAssertEqual(VolumeUnit.fluidOunces.format(millilitres: 236.588), "8.0 fl oz")
    }
}
