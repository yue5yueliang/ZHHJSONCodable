//
//  ZHHJSONHexColor.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  十六进制颜色字符串 ↔ UIColor。
//

import UIKit

/// 十六进制颜色字符串 ↔ UIColor
@propertyWrapper
public struct ZHHJSONHexColor: Codable {
    public var wrappedValue: UIColor?
    /// 编码时是否带 `#` 前缀（默认带）
    public var encodePrefixed: Bool

    /// 用初始值与是否带前缀标志构造包装器
    public init(wrappedValue: UIColor?, encodePrefixed: Bool = true) {
        self.wrappedValue = wrappedValue
        self.encodePrefixed = encodePrefixed
    }

    /// 从解码器构造；主路径直接解析节点，原生路径按字符串解析
    public init(from decoder: Decoder) throws {
        // 主路径：直接从节点解析
        if let impl = decoder as? FlexibleDecoderImpl {
            wrappedValue = ZHHJSONHexColorTransform.color(from: impl.node)
            encodePrefixed = true
            return
        }
        // 原生路径：按字符串解析
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            wrappedValue = ZHHJSONHexColorTransform.color(from: .string(text))
        } else {
            wrappedValue = nil
        }
        encodePrefixed = true
    }

    /// 编码为十六进制字符串；nil 或转换失败时编码 null
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        guard let color = wrappedValue, let hex = ZHHJSONHexColorTransform.hex(from: color, prefixed: encodePrefixed) else {
            try container.encodeNil()
            return
        }
        try container.encode(hex)
    }
}

/// 十六进制颜色值转换器，可作为 `valueMapping()` 的转换器使用
public struct ZHHJSONHexColorTransform: ZHHJSONTransforming {
    public init() {}

    /// 十六进制字符串转 UIColor
    public func fromJSON(_ value: Any) -> Any? {
        ZHHJSONHexColorTransform.color(from: JSONNode.from(value))
    }

    /// UIColor 转带 `#` 前缀的十六进制字符串
    public func toJSON(_ value: Any) -> Any? {
        guard let color = value as? UIColor else { return nil }
        return ZHHJSONHexColorTransform.hex(from: color, prefixed: true)
    }

    /// 字符串转 UIColor：支持 3/4/6/8 位十六进制，可带 # 或 0x 前缀
    static func color(from node: JSONNode) -> UIColor? {
        guard var text = JSONTypeConverter.string(node) else { return nil }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 去掉 # / 0x 前缀后按 16 进制解析
        if text.hasPrefix("#") { text.removeFirst() }
        if text.lowercased().hasPrefix("0x") { text = String(text.dropFirst(2)) }
        guard let value = UInt64(text, radix: 16) else { return nil }
        switch text.count {
        case 3:
            let r = CGFloat((value >> 8) & 0xF) / 15
            let g = CGFloat((value >> 4) & 0xF) / 15
            let b = CGFloat(value & 0xF) / 15
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        case 4:
            let r = CGFloat((value >> 12) & 0xF) / 15
            let g = CGFloat((value >> 8) & 0xF) / 15
            let b = CGFloat((value >> 4) & 0xF) / 15
            let a = CGFloat(value & 0xF) / 15
            return UIColor(red: r, green: g, blue: b, alpha: a)
        case 6:
            return rgb(value, alpha: 1)
        case 8:
            return rgb(value >> 8, alpha: CGFloat(value & 0xFF) / 255)
        default:
            return nil
        }
    }

    /// UIColor 转十六进制字符串；alpha 非满时输出 8 位
    static func hex(from color: UIColor, prefixed: Bool) -> String? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let red = Int((r * 255).rounded())
        let green = Int((g * 255).rounded())
        let blue = Int((b * 255).rounded())
        let alpha = Int((a * 255).rounded())
        let body = alpha < 255
            ? String(format: "%02X%02X%02X%02X", red, green, blue, alpha)
            : String(format: "%02X%02X%02X", red, green, blue)
        return prefixed ? "#\(body)" : body
    }

    /// 6 位 RGB 值按 8 位分量拆解构造 UIColor
    private static func rgb(_ value: UInt64, alpha: CGFloat) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }
}
