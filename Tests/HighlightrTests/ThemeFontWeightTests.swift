import AppKit
import XCTest
@testable import Highlightr

@MainActor
final class ThemeFontWeightTests: XCTestCase {
    func testTokenThemeAfterInitNotifiesThemeChanged() throws {
        let highlightr = try XCTUnwrap(Highlightr())
        var changedTheme: Theme?

        highlightr.themeChanged = { theme in
            changedTheme = theme
        }

        highlightr.setTokenTheme(
            HighlightrTokenTheme(
                foregroundColor: .black,
                backgroundColor: .white,
                tokenStyles: [:]
            )
        )

        XCTAssertIdentical(changedTheme, highlightr.theme)
    }

    func testTokenThemeAfterInitInvalidatesHighlightCache() throws {
        let highlightr = try XCTUnwrap(Highlightr())
        let code = "let value = 1"
        _ = try XCTUnwrap(highlightr.highlight(code, as: "swift"))
        let foregroundColor = NSColor(calibratedRed: 0.12, green: 0.34, blue: 0.56, alpha: 1)

        highlightr.setTokenTheme(
            HighlightrTokenTheme(
                foregroundColor: foregroundColor,
                backgroundColor: .white,
                tokenStyles: [
                    "hljs-keyword": HighlightrTokenStyle(
                        foregroundColor: foregroundColor
                    )
                ]
            )
        )

        let highlighted = try XCTUnwrap(highlightr.highlight(code, as: "swift"))

        XCTAssertIdentical(
            highlighted.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor,
            foregroundColor
        )
    }

    func testTokenThemeOverridesForegroundColors() throws {
        let theme = Theme(themeString: ".hljs{color:#000}.hljs-keyword{color:#ff0000;}")
        let foregroundColor = NSColor.green
        let keywordColor = NSColor.blue

        theme.tokenTheme = HighlightrTokenTheme(
            foregroundColor: foregroundColor,
            backgroundColor: .white,
            tokenStyles: [
                "hljs-keyword": HighlightrTokenStyle(
                    foregroundColor: keywordColor
                )
            ]
        )

        let plain = theme.applyStyleToString("plain", styleList: ["hljs"])
        let keyword = theme.applyStyleToString("keyword", styleList: ["hljs", "hljs-keyword"])

        XCTAssertIdentical(
            plain.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor,
            foregroundColor
        )
        XCTAssertIdentical(
            keyword.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor,
            keywordColor
        )
    }

    func testTokenThemeUsesBackgroundAsThemeBackgroundOnlyForRoot() throws {
        let theme = Theme(themeString: ".hljs{background:#000;color:#fff}")
        let backgroundColor = NSColor.red

        theme.tokenTheme = HighlightrTokenTheme(
            foregroundColor: .black,
            backgroundColor: backgroundColor,
            tokenStyles: [:]
        )

        let attributed = theme.applyStyleToString("plain", styleList: ["hljs"])

        XCTAssertIdentical(theme.themeBackgroundColor, backgroundColor)
        XCTAssertNil(attributed.attribute(.backgroundColor, at: 0, effectiveRange: nil))
    }

    func testTokenThemeAppliesNonRootBackgroundColors() throws {
        let theme = Theme(themeString: "")
        let backgroundColor = NSColor.yellow

        theme.tokenTheme = HighlightrTokenTheme(
            foregroundColor: .black,
            backgroundColor: .white,
            tokenStyles: [
                "hljs-addition": HighlightrTokenStyle(
                    backgroundColor: backgroundColor
                )
            ]
        )

        let attributed = theme.applyStyleToString("addition", styleList: ["hljs", "hljs-addition"])

        XCTAssertIdentical(
            attributed.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor,
            backgroundColor
        )
    }

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
