//
//  ImageHelper.swift
//  Agent Ring
//

import AppKit

/// 图像处理辅助工具
/// 提供应用图标创建、缓存等功能
enum ImageHelper {
    // MARK: - App Icon

    /// 创建应用图标（非模板模式）
    /// - Parameter size: 图标大小
    /// - Returns: 指定大小的应用图标，如果无法加载则返回 nil
    static func createAppIcon(size: CGFloat) -> NSImage? {
        guard let appIcon = NSImage(named: "AppIcon") else { return nil }
        guard let iconCopy = appIcon.copy() as? NSImage else { return nil }
        iconCopy.isTemplate = false
        iconCopy.size = NSSize(width: size, height: size)
        return iconCopy
    }

    /// 创建应用图标（非模板模式，指定宽高）
    /// - Parameters:
    ///   - width: 图标宽度
    ///   - height: 图标高度
    /// - Returns: 指定尺寸的应用图标，如果无法加载则返回 nil
    static func createAppIcon(width: CGFloat, height: CGFloat) -> NSImage? {
        guard let appIcon = NSImage(named: "AppIcon") else { return nil }
        guard let iconCopy = appIcon.copy() as? NSImage else { return nil }
        iconCopy.isTemplate = false
        iconCopy.size = NSSize(width: width, height: height)
        return iconCopy
    }

    // MARK: - Codex Icon

    static func createCodexIcon(size: CGFloat) -> NSImage? {
        createSquareIcon(named: "CodexIcon", size: size, isTemplate: false, sourceInset: 2)
    }

    static func createCursorIcon(size: CGFloat, isTemplate: Bool) -> NSImage? {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 1, y: 1, width: size - 2, height: size - 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
        if isTemplate {
            NSColor.black.setFill()
        } else {
            NSColor(red: 124/255.0, green: 58/255.0, blue: 237/255.0, alpha: 1).setFill()
        }
        path.fill()

        let font = NSFont.systemFont(ofSize: size * 0.55, weight: .bold)
        let letter = "C"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: isTemplate ? NSColor.white : NSColor.white
        ]
        let textSize = letter.size(withAttributes: attrs)
        letter.draw(
            at: NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2 - 0.5),
            withAttributes: attrs
        )

        image.unlockFocus()
        image.isTemplate = isTemplate
        return image
    }

    static func createGlmIcon(size: CGFloat, isTemplate: Bool) -> NSImage? {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 1, y: 1, width: size - 2, height: size - 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
        if isTemplate {
            NSColor.black.setFill()
        } else {
            NSColor(red: 62/255.0, green: 95/255.0, blue: 251/255.0, alpha: 1).setFill()
        }
        path.fill()

        let font = NSFont.systemFont(ofSize: size * 0.55, weight: .bold)
        let letter = "G"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = letter.size(withAttributes: attrs)
        letter.draw(
            at: NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2 - 0.5),
            withAttributes: attrs
        )

        image.unlockFocus()
        image.isTemplate = isTemplate
        return image
    }

    static func createKimiIcon(size: CGFloat, isTemplate: Bool) -> NSImage? {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 1, y: 1, width: size - 2, height: size - 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
        if isTemplate {
            NSColor.black.setFill()
        } else {
            NSColor(red: 125/255.0, green: 95/255.0, blue: 255/255.0, alpha: 1).setFill()
        }
        path.fill()

        let font = NSFont.systemFont(ofSize: size * 0.55, weight: .bold)
        let letter = "K"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = letter.size(withAttributes: attrs)
        letter.draw(
            at: NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2 - 0.5),
            withAttributes: attrs
        )

        image.unlockFocus()
        image.isTemplate = isTemplate
        return image
    }

    static func createAntigravityIcon(size: CGFloat, isTemplate: Bool) -> NSImage? {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 1, y: 1, width: size - 2, height: size - 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
        if isTemplate {
            NSColor.black.setFill()
        } else {
            NSColor(red: 26/255.0, green: 115/255.0, blue: 232/255.0, alpha: 1).setFill()
        }
        path.fill()

        let font = NSFont.systemFont(ofSize: size * 0.55, weight: .bold)
        let letter = "A"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = letter.size(withAttributes: attrs)
        letter.draw(
            at: NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2 - 0.5),
            withAttributes: attrs
        )

        image.unlockFocus()
        image.isTemplate = isTemplate
        return image
    }

    /// 从资源中创建正方形图标。部分透明 PNG 的边缘 RGB 不是透明白，
    /// 直接缩放时会被 AppKit 采样成细暗线，因此这里先居中裁方并略微内收。
    static func createSquareIcon(named name: String, size: CGFloat, isTemplate: Bool, sourceInset: CGFloat = 0) -> NSImage? {
        guard let source = NSImage(named: name) else { return nil }
        let targetSize = NSSize(width: size, height: size)
        let image = NSImage(size: targetSize)

        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: targetSize).fill()

        let sourceSize = source.size
        let side = min(sourceSize.width, sourceSize.height) - sourceInset * 2
        let cropRect = NSRect(
            x: (sourceSize.width - side) / 2,
            y: (sourceSize.height - side) / 2,
            width: side,
            height: side
        )

        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: cropRect,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: false,
            hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]
        )
        image.unlockFocus()
        image.isTemplate = isTemplate
        return image
    }

    // MARK: - System Images

    /// 创建系统符号图像
    /// - Parameters:
    ///   - systemName: SF Symbols 名称
    ///   - size: 图像大小
    ///   - weight: 符号粗细
    /// - Returns: 创建的系统图像，如果无法加载则返回 nil
    static func createSystemImage(
        systemName: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular
    ) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        return NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }
}
