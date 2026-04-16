import AppKit
import XCTest
@testable import Highlightr

@MainActor
final class ThemeFontWeightTests: XCTestCase {
    func testMonospacedSystemMediumWeightSurvives() throws {
        let theme = Theme(themeString: ".hljs-number{font-weight:500;}")
        theme.setCodeFont(NSFont.monospacedSystemFont(ofSize: 15, weight: .regular))

        let attributed = theme.applyStyleToString("1", styleList: ["hljs-number"])
        let font = try XCTUnwrap(attributed.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)

        XCTAssertGreaterThan(fontWeight(for: font), 0.05)
        XCTAssertEqual(font.familyName, theme.codeFont.familyName)
    }

    func testMonospacedSystemLightItalicSurvives() throws {
        let theme = Theme(themeString: ".hljs-number{font-weight:300;font-style:italic;}")
        theme.setCodeFont(NSFont.monospacedSystemFont(ofSize: 15, weight: .regular))

        let attributed = theme.applyStyleToString("1", styleList: ["hljs-number"])
        let font = try XCTUnwrap(attributed.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)

        XCTAssertLessThan(fontWeight(for: font), -0.05)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.italic))
        XCTAssertEqual(font.familyName, theme.codeFont.familyName)
    }

    private func fontWeight(for font: NSFont) -> CGFloat {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any]
        let weight = traits?[.weight] as? NSNumber
        return CGFloat(weight?.doubleValue ?? 0)
    }
}
