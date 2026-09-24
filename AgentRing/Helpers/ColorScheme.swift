//
//  ColorScheme.swift
//  Agent Ring
//

import SwiftUI
import AppKit

enum UsageColorScheme {

    // Apple Watch Activity 环近似色（HIG 标签色量级）：
    // Move 红粉 / Exercise 荧光绿 / Stand 亮青
    private static let activityMove = NSColor(red: 250/255.0, green: 17/255.0, blue: 79/255.0, alpha: 1.0)
    private static let activityExercise = NSColor(red: 146/255.0, green: 232/255.0, blue: 42/255.0, alpha: 1.0)
    private static let activityStand = NSColor(red: 0/255.0, green: 212/255.0, blue: 255/255.0, alpha: 1.0)
    private static let activityAmber = NSColor(red: 255/255.0, green: 159/255.0, blue: 10/255.0, alpha: 1.0)

    // Dashboard 使用低饱和、相近明度的安静色板；菜单栏仍保留高辨识度 Activity 色。
    private static let dashboardCodexGreen = NSColor(red: 113/255.0, green: 143/255.0, blue: 102/255.0, alpha: 1.0)
    private static let dashboardCodexTeal = NSColor(red: 102/255.0, green: 139/255.0, blue: 145/255.0, alpha: 1.0)
    private static let dashboardOchre = NSColor(red: 161/255.0, green: 132/255.0, blue: 98/255.0, alpha: 1.0)
    private static let dashboardCursorRose = NSColor(red: 183/255.0, green: 103/255.0, blue: 118/255.0, alpha: 1.0)
    private static let dashboardAntigravityBlue = NSColor(red: 97/255.0, green: 127/255.0, blue: 168/255.0, alpha: 1.0)
    private static let dashboardAntigravityViolet = NSColor(red: 129/255.0, green: 116/255.0, blue: 155/255.0, alpha: 1.0)
    private static let dashboardThirdPartyTerracotta = NSColor(red: 168/255.0, green: 120/255.0, blue: 93/255.0, alpha: 1.0)
    private static let dashboardThirdPartyTeal = NSColor(red: 102/255.0, green: 138/255.0, blue: 130/255.0, alpha: 1.0)

    static func isDarkMode(for statusButton: NSStatusBarButton? = nil) -> Bool {
        if let button = statusButton,
           let appearance = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
            return appearance == .darkAqua
        }
        return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    static var isDarkMode: Bool {
        isDarkMode(for: nil)
    }

    /// Codex 5 小时：Exercise 绿
    static func codexPrimaryColor(_ percentage: Double) -> NSColor {
        warningTint(activityExercise, percentage: percentage)
    }

    static func codexPrimaryColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(dashboardCodexGreen, opacity: opacity)
    }

    static func codexPrimaryColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        adaptive(codexPrimaryColor(percentage), for: statusButton)
    }

    /// Codex 7 天：Stand 青
    static func codexSecondaryColor(_ percentage: Double) -> NSColor {
        warningTint(activityStand, percentage: percentage)
    }

    static func codexSecondaryColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(dashboardCodexTeal, opacity: opacity)
    }

    /// Dashboard 双环内环：外环绿的压暗版
    static func codexPairedInnerColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(darkened(dashboardCodexGreen, by: 0.92), opacity: opacity)
    }

    static func codexSecondaryColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        adaptive(codexSecondaryColor(percentage), for: statusButton)
    }

    /// Extra：高饱和琥珀
    static func codexExtraUsageColor(_ percentage: Double) -> NSColor {
        warningTint(activityAmber, percentage: percentage)
    }

    static func codexExtraUsageColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(dashboardOchre, opacity: opacity)
    }

    static func codexExtraUsageColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        adaptive(codexExtraUsageColor(percentage), for: statusButton)
    }

    /// Cursor 套餐：Move 红粉
    static func cursorIncludedColor(_ percentage: Double) -> NSColor {
        warningTint(activityMove, percentage: percentage)
    }

    static func cursorIncludedColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(dashboardCursorRose, opacity: opacity)
    }

    static func cursorIncludedColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        adaptive(cursorIncludedColor(percentage), for: statusButton)
    }

    /// Cursor 按需：琥珀
    static func cursorOnDemandColor(_ percentage: Double) -> NSColor {
        warningTint(activityAmber, percentage: percentage)
    }

    static func cursorOnDemandColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(dashboardOchre, opacity: opacity)
    }

    /// Dashboard 双环内环：外环红粉的压暗版
    static func cursorPairedInnerColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(darkened(dashboardCursorRose, by: 0.92), opacity: opacity)
    }

    static func cursorOnDemandColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        adaptive(cursorOnDemandColor(percentage), for: statusButton)
    }

    // GLM Coding Plan：智谱 z.ai 品牌青蓝（官网亮端 ≈#00d4ff）压低饱和的 Dashboard 版；
    // 色相与 Antigravity 灰蓝、Kimi 紫错开，避免弹窗并排时混淆
    private static let dashboardGlmBlue = NSColor(red: 78/255.0, green: 156/255.0, blue: 212/255.0, alpha: 1.0)

    static func glmPrimaryColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(dashboardGlmBlue, opacity: opacity)
    }

    /// Dashboard 双环内环：外环蓝的压暗版
    static func glmPairedInnerColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(darkened(dashboardGlmBlue, by: 0.92), opacity: opacity)
    }

    // Kimi Coding Plan：紫色为弹窗调色板区分色而非品牌色（Kimi 官方视觉是
    // 深蓝/冰蓝 + 黑白，冷蓝系已被 Antigravity/GLM 占用），此处为压低饱和的 Dashboard 版
    private static let dashboardKimiViolet = NSColor(red: 139/255.0, green: 118/255.0, blue: 206/255.0, alpha: 1.0)

    static func kimiPrimaryColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(dashboardKimiViolet, opacity: opacity)
    }

    /// Dashboard 双环内环：外环紫的压暗版
    static func kimiPairedInnerColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(darkened(dashboardKimiViolet, by: 0.92), opacity: opacity)
    }

    /// Antigravity 5 小时：Google 科技蓝
    private static let activityAntigravityBlue = NSColor(red: 26/255.0, green: 115/255.0, blue: 232/255.0, alpha: 1.0)
    /// Antigravity 7 天：亮紫
    private static let activityAntigravityPurple = NSColor(red: 168/255.0, green: 85/255.0, blue: 247/255.0, alpha: 1.0)
    /// Antigravity Claude/GPT 5 小时：暖珊瑚橙 (Claude 标识色)
    private static let activityAntigravityThirdPartyCoral = NSColor(red: 217/255.0, green: 119/255.0, blue: 70/255.0, alpha: 1.0)
    /// Antigravity Claude/GPT 7 天：青碧绿 (OpenAI / GPT 标识色)
    private static let activityAntigravityThirdPartyTeal = NSColor(red: 16/255.0, green: 163/255.0, blue: 127/255.0, alpha: 1.0)

    static func antigravityPrimaryColor(_ percentage: Double) -> NSColor {
        warningTint(activityAntigravityBlue, percentage: percentage)
    }

    static func antigravityPrimaryColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(dashboardAntigravityBlue, opacity: opacity)
    }

    static func antigravityPrimaryColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        adaptive(antigravityPrimaryColor(percentage), for: statusButton)
    }

    static func antigravitySecondaryColor(_ percentage: Double) -> NSColor {
        warningTint(activityAntigravityPurple, percentage: percentage)
    }

    static func antigravitySecondaryColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(dashboardAntigravityViolet, opacity: opacity)
    }

    /// Dashboard 双环内环：外环蓝的压暗版
    static func antigravityPairedInnerColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(darkened(dashboardAntigravityBlue, by: 0.92), opacity: opacity)
    }

    static func antigravitySecondaryColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        adaptive(antigravitySecondaryColor(percentage), for: statusButton)
    }

    static func antigravityThirdPartyPrimaryColor(_ percentage: Double) -> NSColor {
        warningTint(activityAntigravityThirdPartyCoral, percentage: percentage)
    }

    static func antigravityThirdPartyPrimaryColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(dashboardThirdPartyTerracotta, opacity: opacity)
    }

    static func antigravityThirdPartyPrimaryColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        adaptive(antigravityThirdPartyPrimaryColor(percentage), for: statusButton)
    }

    static func antigravityThirdPartySecondaryColor(_ percentage: Double) -> NSColor {
        warningTint(activityAntigravityThirdPartyTeal, percentage: percentage)
    }

    static func antigravityThirdPartySecondaryColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(dashboardThirdPartyTeal, opacity: opacity)
    }

    /// Dashboard 双环内环：外环珊瑚橙的压暗版
    static func antigravityThirdPartyPairedInnerColorSwiftUI(_ percentage: Double, opacity: Double = 1.0) -> Color {
        color(darkened(dashboardThirdPartyTerracotta, by: 0.92), opacity: opacity)
    }

    static func antigravityThirdPartySecondaryColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        adaptive(antigravityThirdPartySecondaryColor(percentage), for: statusButton)
    }

    private static func adaptive(_ baseColor: NSColor, for statusButton: NSStatusBarButton?) -> NSColor {
        isDarkMode(for: statusButton) ? baseColor.adjustedForDarkMode() : baseColor
    }

    /// 菜单栏：保持 Activity 环的高饱和霓虹感，浅色栏也不再压暗。
    static func menuBarAccent(_ baseColor: NSColor, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let adapted = adaptive(baseColor, for: statusButton)
        guard let rgb = adapted.usingColorSpace(.deviceRGB) else { return adapted }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return NSColor(
            hue: hue,
            saturation: min(1, max(0.88, saturation * 1.05)),
            brightness: min(1, max(0.78, brightness)),
            alpha: alpha
        )
    }

    /// 同一色相压暗亮度，让内外环接近而不跳色
    private static func darkened(_ base: NSColor, by factor: CGFloat) -> NSColor {
        guard let rgb = base.usingColorSpace(.deviceRGB) else { return base }
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return NSColor(
            hue: hue,
            saturation: saturation,
            brightness: max(0, min(1, brightness * factor)),
            alpha: alpha
        )
    }

    /// 高占用时略偏暖警示，但不压成脏色
    private static func warningTint(_ base: NSColor, percentage: Double) -> NSColor {
        guard percentage >= 90, let rgb = base.usingColorSpace(.deviceRGB) else { return base }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return NSColor(
            hue: hue,
            saturation: min(1, saturation + 0.05),
            brightness: min(1, brightness * 0.92),
            alpha: alpha
        )
    }

    private static func color(_ nsColor: NSColor, opacity: Double) -> Color {
        guard let rgb = nsColor.usingColorSpace(.deviceRGB) else {
            return Color(nsColor).opacity(opacity)
        }
        return Color(
            red: Double(rgb.redComponent),
            green: Double(rgb.greenComponent),
            blue: Double(rgb.blueComponent)
        )
        .opacity(opacity)
    }
}

extension NSColor {
    func adjustedForDarkMode() -> NSColor {
        guard let rgbColor = usingColorSpace(.deviceRGB) else {
            return self
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let adjustedBrightness = min(1.0, max(0.82, brightness * 1.08))
        let adjustedSaturation = min(1.0, saturation)

        return NSColor(hue: hue, saturation: adjustedSaturation, brightness: adjustedBrightness, alpha: alpha)
    }
}
