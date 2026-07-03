//
//  Theme.swift
//  Pods
//
//  Created by Illanes, J.P. on 4/24/16.
//
//

import Foundation

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    import UIKit
    /// Typealias for UIColor
    public typealias RPColor = UIColor
    /// Typealias for UIFont
    public typealias RPFont = UIFont
#else
    import AppKit
    /// Typealias for NSColor
    public typealias RPColor = NSColor
    /// Typealias for NSFont
    public typealias RPFont = NSFont

#endif

private typealias RPThemeDict = [String: [AnyHashable: AnyObject]]
private typealias RPThemeStringDict = [String:[String:String]]

private struct DisplayP3Color {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat
}

/// A concrete set of attributes to apply to a highlight.js token class.
public struct HighlightrTokenStyle {
    public var foregroundColor: RPColor?
    public var backgroundColor: RPColor?
    public var fontWeight: Int?
    public var isItalic: Bool

    public init(
        foregroundColor: RPColor? = nil,
        backgroundColor: RPColor? = nil,
        fontWeight: Int? = nil,
        isItalic: Bool = false
    ) {
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.fontWeight = fontWeight
        self.isItalic = isItalic
    }
}

/// A host-provided theme that lets apps own syntax colors without shipping
/// highlight.js CSS themes. Keys are highlight.js class names, such as
/// "hljs-keyword", "hljs-string", or custom language classes.
public struct HighlightrTokenTheme {
    public var foregroundColor: RPColor
    public var backgroundColor: RPColor
    public var tokenStyles: [String: HighlightrTokenStyle]

    public init(
        foregroundColor: RPColor,
        backgroundColor: RPColor,
        tokenStyles: [String: HighlightrTokenStyle]
    ) {
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.tokenStyles = tokenStyles
    }
}

/// Theme parser, can be used to configure the theme parameters. 
open class Theme {
    internal let theme : String
    internal var lightTheme : String!
    internal var changeHandler: (() -> Void)?
    
    /// Regular font to be used by this theme
    open var codeFont : RPFont!
    /// Bold font to be used by this theme
    open var boldCodeFont : RPFont!
    /// Italic font to be used by this theme
    open var italicCodeFont : RPFont!
    /// Bold italic font to be used by this theme
    open var boldItalicCodeFont : RPFont!
    
    private var themeDict : RPThemeDict!
    private var strippedTheme : RPThemeStringDict!

    /// Optional host-provided token theme. When set, its colors and token
    /// styles override colors parsed from the CSS theme.
    open var tokenTheme: HighlightrTokenTheme? {
        didSet {
            rebuildTheme()
            changeHandler?()
        }
    }
    
    /// Default background color for the current theme.
    open var themeBackgroundColor : RPColor!

    /// Default foreground (text) color for the current theme.
    open var themeForegroundColor : RPColor!

    /// Keyword color for the current theme (e.g. hljs-keyword foreground).
    open var keywordColor: RPColor? {
        themeDict?["hljs-keyword"]?[NSAttributedString.Key.foregroundColor] as? RPColor
    }
    
    /**
     Initialize the theme with the given theme name.
     
     - parameter themeString: Theme to use.
     */
    init(themeString: String)
    {
        theme = themeString
        setCodeFont(RPFont(name: "Courier", size: 14)!)
        strippedTheme = stripTheme(themeString)
        lightTheme = strippedThemeToString(strippedTheme)
        rebuildTheme()
    }
    
    /**
     Changes the theme font. This will try to automatically populate the codeFont, boldCodeFont and italicCodeFont properties based on the provided font.
     
     - parameter font: UIFont (iOS or tvOS) or NSFont (OSX)
     */
    open func setCodeFont(_ font: RPFont)
    {
        codeFont = font
        
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        let boldDescriptor = UIFontDescriptor(fontAttributes: [UIFontDescriptor.AttributeName.family:font.familyName,
                                                                UIFontDescriptor.AttributeName.face:"Bold"])
        let italicDescriptor = UIFontDescriptor(fontAttributes: [UIFontDescriptor.AttributeName.family:font.familyName,
                                                                 UIFontDescriptor.AttributeName.face:"Italic"])
        let obliqueDescriptor = UIFontDescriptor(fontAttributes: [UIFontDescriptor.AttributeName.family:font.familyName,
                                                                  UIFontDescriptor.AttributeName.face:"Oblique"])
        #else
        let boldDescriptor = NSFontDescriptor(fontAttributes: [.family:font.familyName!,
                                                                   .face:"Bold"])
        let italicDescriptor = NSFontDescriptor(fontAttributes: [.family:font.familyName!,
                                                                     .face:"Italic"])
        let obliqueDescriptor = NSFontDescriptor(fontAttributes: [.family:font.familyName!,
                                                                      .face:"Oblique"])
        #endif
        
        boldCodeFont = RPFont(descriptor: boldDescriptor, size: font.pointSize)
        italicCodeFont = RPFont(descriptor: italicDescriptor, size: font.pointSize)
        
        if(italicCodeFont == nil || italicCodeFont.familyName != font.familyName)
        {
            italicCodeFont = RPFont(descriptor: obliqueDescriptor, size: font.pointSize)
        }
        if(italicCodeFont == nil)
        {
            italicCodeFont = font
        }
        
        if(boldCodeFont == nil)
        {
            boldCodeFont = font
        }

        // Build bold+italic combined font
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        let boldItalicDescriptor = boldCodeFont.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic])
        boldItalicCodeFont = boldItalicDescriptor.map { RPFont(descriptor: $0, size: font.pointSize) } ?? boldCodeFont
        #else
        let boldItalicDescriptor = boldCodeFont.fontDescriptor.withSymbolicTraits(.bold.union(.italic))
        boldItalicCodeFont = RPFont(descriptor: boldItalicDescriptor, size: font.pointSize) ?? boldCodeFont
        #endif

        if strippedTheme != nil
        {
            rebuildTheme()
            changeHandler?()
        }
    }
    
    internal func applyStyleToString(_ string: String, styleList: [String]) -> NSAttributedString
    {
        let returnString : NSAttributedString

        if styleList.count > 0
        {
            var attrs = [AttributedStringKey: Any]()
            attrs[.font] = codeFont

            // Pre-resolve compound selectors once instead of checking per-style.
            // hljs v11 uses "hljs-title class_" / "hljs-title function_" on the element
            // itself, while older versions nested ".hljs-class .hljs-title".
            let hasTitle = styleList.contains("hljs-title")
            let compoundKey: String? = {
                if hasTitle {
                    if styleList.contains("hljs-function") || styleList.contains("function_"),
                       themeDict["hljs-function-hljs-title"] != nil {
                        return "hljs-function-hljs-title"
                    }
                    if styleList.contains("hljs-class") || styleList.contains("class_"),
                       themeDict["hljs-class-hljs-title"] != nil {
                        return "hljs-class-hljs-title"
                    }
                }
                return nil
            }()

            for style in styleList
            {
                let resolvedStyle = compoundKey ?? style

                if let themeStyle = themeDict[resolvedStyle] as? [AttributedStringKey: Any]
                {
                    for (attrName, attrValue) in themeStyle
                    {
                        attrs.updateValue(attrValue, forKey: attrName)
                    }
                }
            }

            returnString = NSAttributedString(string: string, attributes:attrs )
        }
        else
        {
			returnString = NSAttributedString(string: string, attributes:[AttributedStringKey.font:codeFont as Any] )
        }

        return returnString
    }
    
    private func stripTheme(_ themeString : String) -> [String:[String:String]]
    {
        let objcString = (themeString as NSString)
        let cssRegex = try! NSRegularExpression(pattern: "(?:(\\.[a-zA-Z0-9\\-_]*(?:[, ]\\.[a-zA-Z0-9\\-_]*)*)\\{([^\\}]*?)\\})", options:[.caseInsensitive])
        
        let results = cssRegex.matches(in: themeString,
                                               options: [.reportCompletion],
                                               range: NSMakeRange(0, objcString.length))
        
        var resultDict = [String:[String:String]]()
        
        for result in results {
            if(result.numberOfRanges == 3)
            {
                var attributes = [String:String]()
                let cssPairs = objcString.substring(with: result.range(at: 2)).components(separatedBy: ";")
                for pair in cssPairs {
                    let cssPropComp = pair.components(separatedBy: ":")
                    if(cssPropComp.count == 2)
                    {
                        attributes[cssPropComp[0]] = cssPropComp[1]
                    }

                }
                if attributes.count > 0
                {
                    let selector = objcString.substring(with: result.range(at: 1))
                    var existing = resultDict[selector] ?? [String:String]()
                    for (k, v) in attributes { existing[k] = v }
                    resultDict[selector] = existing
                }
                
            }
            
        }
        
        var returnDict = [String:[String:String]]()

        for (keys,result) in resultDict
        {
            let keyArray = keys.replacingOccurrences(of: " ", with: ",").components(separatedBy: ",")
            for key in keyArray {
                var key = key
                if keyArray.contains(".hljs-title") && keyArray.contains(".hljs-function") {
                    key = "hljs-function-hljs-title"
                }

                if keyArray.contains(".hljs-title") && keyArray.contains(".hljs-class") {
                    key = "hljs-class-hljs-title"
                }

                var props : [String:String]?
                props = returnDict[key]
                if props == nil {
                    props = [String:String]()
                }
                
                for (pName, pValue) in result
                {
                    props!.updateValue(pValue, forKey: pName)
                }
                returnDict[key] = props!
            }
        }
        
        return returnDict
    }
    
    private func strippedThemeToString(_ theme: RPThemeStringDict) -> String
    {
        var resultString = ""
        for (key, props) in theme {
            resultString += key+"{"
            for (cssProp, val) in props
            {
                if(key != ".hljs" || (cssProp.lowercased() != "background-color" && cssProp.lowercased() != "background"))
                {
                    resultString += "\(cssProp):\(val);"
                }
            }
            resultString+="}"
        }
        return resultString
    }
    
    private func strippedThemeToTheme(_ theme: RPThemeStringDict) -> RPThemeDict
    {
        var returnTheme = RPThemeDict()
        for (className, props) in theme
        {
            var keyProps = [AttributedStringKey: AnyObject]()
            var cssWeight: Int? = nil
            var wantItalic = false
            for (key, prop) in props
            {
                switch key
                {
                case "color":
                    keyProps[.foregroundColor] = colorWithHexString(prop)
                case "font-weight":
                    switch prop {
                    case "bold", "bolder":
                        cssWeight = 700
                    case "normal", "lighter":
                        cssWeight = 400
                    default:
                        if let w = Int(prop) { cssWeight = w }
                    }
                case "font-style":
                    switch prop {
                    case "italic", "oblique":
                        wantItalic = true
                    default:
                        wantItalic = false
                    }
                case "background-color", "background":
                    // Skip per-character background on .hljs — the editor view
                    // sets its own background; per-character bg paints over the
                    // active-line indicator and selection highlights.
                    if className != ".hljs" {
                        keyProps[.backgroundColor] = colorWithHexString(prop)
                    }
                default:
                    break
                }
            }
            // Build font with the requested weight + italic
            if cssWeight != nil || wantItalic {
                let weight = cssWeight ?? 400
                let font = fontForWeight(weight, italic: wantItalic)
                keyProps[.font] = font
            }
            if keyProps.count > 0
            {
                let key = className.replacingOccurrences(of: ".", with: "")
                returnTheme[key] = keyProps
            }
        }
        return returnTheme
    }

    private func rebuildTheme() {
        guard strippedTheme != nil else { return }

        themeDict = strippedThemeToTheme(strippedTheme)
        applyParsedThemeColors()
        applyTokenThemeIfNeeded()
    }

    private func applyParsedThemeColors() {
        let bkgColorHex = strippedTheme[".hljs"]?["background"]
            ?? strippedTheme[".hljs"]?["background-color"]
        if let bkgColorHex {
            themeBackgroundColor = colorWithHexString(bkgColorHex)
        } else {
            themeBackgroundColor = RPColor.white
        }

        let fgColorHex = strippedTheme[".hljs"]?["color"]
        if let fgColorHex {
            themeForegroundColor = colorWithHexString(fgColorHex)
        } else {
            themeForegroundColor = RPColor.black
        }
    }

    private func applyTokenThemeIfNeeded() {
        guard let tokenTheme else { return }

        themeForegroundColor = tokenTheme.foregroundColor
        themeBackgroundColor = tokenTheme.backgroundColor
        merge(
            HighlightrTokenStyle(foregroundColor: tokenTheme.foregroundColor),
            intoStyleNamed: "hljs"
        )

        for (name, style) in tokenTheme.tokenStyles {
            merge(style, intoStyleNamed: name)
        }
    }

    private func merge(
        _ tokenStyle: HighlightrTokenStyle,
        intoStyleNamed styleName: String
    ) {
        let key = normalizedStyleName(styleName)
        var attributes = (themeDict[key] as? [AttributedStringKey: AnyObject])
            ?? [AttributedStringKey: AnyObject]()

        if let foregroundColor = tokenStyle.foregroundColor {
            attributes[.foregroundColor] = foregroundColor
        }

        if let backgroundColor = tokenStyle.backgroundColor, key != "hljs" {
            attributes[.backgroundColor] = backgroundColor
        }

        if tokenStyle.fontWeight != nil || tokenStyle.isItalic {
            attributes[.font] = fontForWeight(
                tokenStyle.fontWeight ?? 400,
                italic: tokenStyle.isItalic
            )
        }

        themeDict[key] = attributes
    }

    private func normalizedStyleName(_ styleName: String) -> String {
        let trimmed = styleName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix(".")
            ? String(trimmed.dropFirst())
            : trimmed
    }
    
    private func fontForCSSStyle(_ fontStyle:String) -> RPFont
    {
        switch fontStyle
        {
            case "bold", "bolder", "600", "700", "800", "900":
                return boldCodeFont
            case "italic", "oblique":
                return italicCodeFont
            default:
                return codeFont
        }
    }

    /// Build a font matching a CSS font-weight (100–900) with optional italic.
    private func fontForWeight(_ cssWeight: Int, italic: Bool) -> RPFont {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        let size = codeFont.pointSize
        let traits: UIFontDescriptor.SymbolicTraits = italic ? .traitItalic : []
        let weightMap: [Int: UIFont.Weight] = [
            100: .ultraLight, 200: .thin, 300: .light, 400: .regular,
            500: .medium, 600: .semibold, 700: .bold, 800: .heavy, 900: .black
        ]
        let uiWeight = weightMap[cssWeight] ?? .regular
        var descriptor = UIFontDescriptor(fontAttributes: [
            .family: codeFont.familyName,
        ]).addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: uiWeight]])
        if let withTraits = descriptor.withSymbolicTraits(traits) {
            descriptor = withTraits
        }
        return UIFont(descriptor: descriptor, size: size)
        #else
        let size = codeFont.pointSize
        let nsWeightMap: [Int: NSFont.Weight] = [
            100: .ultraLight, 200: .thin, 300: .light, 400: .regular,
            500: .medium, 600: .semibold, 700: .bold, 800: .heavy, 900: .black
        ]
        let nsWeight = nsWeightMap[cssWeight] ?? .regular

        if isSystemMonospacedFont(codeFont),
           #available(macOS 10.15, *) {
            return monospacedSystemFont(ofSize: size, weight: nsWeight, italic: italic)
        }

        let family = codeFont.familyName ?? "Menlo"
        var traits = NSFontDescriptor.SymbolicTraits()
        if cssWeight >= 600 { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: family,
            .traits: [NSFontDescriptor.TraitKey.weight: nsWeight]
        ]).withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: size) ?? codeFont
        #endif
    }

    #if os(macOS)
    private func isSystemMonospacedFont(_ font: NSFont) -> Bool {
        font.familyName == ".AppleSystemUIFontMonospaced" ||
            font.fontName.hasPrefix(".AppleSystemUIFontMonospaced")
    }

    @available(macOS 10.15, *)
    private func monospacedSystemFont(
        ofSize size: CGFloat,
        weight: NSFont.Weight,
        italic: Bool
    ) -> NSFont {
        let font = NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        guard italic else { return font }

        let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        return NSFont(descriptor: italicFont.fontDescriptor, size: size) ?? italicFont
    }
    #endif
    
    private func attributeForCSSKey(_ key: String) -> AttributedStringKey
    {
        switch key {
        case "color":
            return .foregroundColor
        case "font-weight":
            return .font
        case "font-style":
            return .font
        case "background-color":
            return .backgroundColor
        case "background":
            return .backgroundColor
        default:
            return .font
        }
    }
    
    private func colorWithHexString (_ hex:String) -> RPColor
    {

        var cString:String = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if let displayP3Color = Self.displayP3Color(cString) {
            return Self.color(displayP3Color: displayP3Color)
        }

        if (cString.hasPrefix("#"))
        {
            cString = (cString as NSString).substring(from: 1)
        }
        else
        {
            switch cString {
            case "white":
                return RPColor(white: 1, alpha: 1)
            case "black":
                return RPColor(white: 0, alpha: 1)
            case "red":
                return RPColor(red: 1, green: 0, blue: 0, alpha: 1)
            case "green":
                return RPColor(red: 0, green: 1, blue: 0, alpha: 1)
            case "blue":
                return RPColor(red: 0, green: 0, blue: 1, alpha: 1)
            default:
                return RPColor.gray
            }
        }
        
        if (cString.count != 6 && cString.count != 3 )
        {
            return RPColor.gray
        }
        
        
        var r:UInt64 = 0, g:UInt64 = 0, b:UInt64 = 0;
        var divisor : CGFloat
        
        if (cString.count == 6 )
        {
        
            let rString = (cString as NSString).substring(to: 2)
            let gString = ((cString as NSString).substring(from: 2) as NSString).substring(to: 2)
            let bString = ((cString as NSString).substring(from: 4) as NSString).substring(to: 2)
            
            Scanner(string: rString).scanHexInt64(&r)
            Scanner(string: gString).scanHexInt64(&g)
            Scanner(string: bString).scanHexInt64(&b)
            
            divisor = 255.0
            
        }else
        {
            let rString = (cString as NSString).substring(to: 1)
            let gString = ((cString as NSString).substring(from: 1) as NSString).substring(to: 1)
            let bString = ((cString as NSString).substring(from: 2) as NSString).substring(to: 1)
            
            Scanner(string: rString).scanHexInt64(&r)
            Scanner(string: gString).scanHexInt64(&g)
            Scanner(string: bString).scanHexInt64(&b)
            
            divisor = 15.0
        }
        
        return RPColor(red: CGFloat(r) / divisor, green: CGFloat(g) / divisor, blue: CGFloat(b) / divisor, alpha: CGFloat(1))        
        
    }

    private static func displayP3Color(_ value: String) -> DisplayP3Color? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("color("), trimmed.hasSuffix(")") else { return nil }

        var inner = String(trimmed.dropFirst("color(".count).dropLast())
        inner = inner.replacingOccurrences(of: "/", with: " / ")
        let parts = inner.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.first?.lowercased() == "display-p3" else { return nil }

        let channels: ArraySlice<String>
        let alphaToken: String?
        if parts.count == 4 {
            channels = parts[1...3]
            alphaToken = nil
        } else if parts.count == 6, parts[4] == "/" {
            channels = parts[1...3]
            alphaToken = parts[5]
        } else {
            return nil
        }

        let parsedChannels = channels.compactMap(displayP3Component)
        guard parsedChannels.count == 3 else { return nil }
        let alpha = alphaToken.flatMap(displayP3Component) ?? 1
        return DisplayP3Color(
            red: parsedChannels[0],
            green: parsedChannels[1],
            blue: parsedChannels[2],
            alpha: alpha
        )
    }

    private static func displayP3Component(_ token: String) -> CGFloat? {
        let isPercent = token.hasSuffix("%")
        let numericToken = isPercent ? String(token.dropLast()) : token
        guard let value = Double(numericToken) else { return nil }
        let normalized = isPercent ? value / 100 : value
        guard (0...1).contains(normalized) else { return nil }
        return CGFloat(normalized)
    }

    private static func color(displayP3Color color: DisplayP3Color) -> RPColor {
        #if os(iOS) || os(tvOS) || os(visionOS)
        return RPColor(displayP3Red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        #elseif os(watchOS)
        return RPColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        #else
        return RPColor(displayP3Red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        #endif
    }
    

}
