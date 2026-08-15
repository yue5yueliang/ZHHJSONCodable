//
//  ZHHJSONTransform.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  值转换：JSON ↔ 模型属性。
//

import Foundation

/// 值转换协议：定义 JSON 值 ↔ 模型属性之间的双向转换
public protocol ZHHJSONTransforming {
    /// JSON 值转属性值；无法转换时返回 nil，由解码方回落默认值
    func fromJSON(_ value: Any) -> Any?
    /// 属性值转 JSON 值；无法转换时返回 nil
    func toJSON(_ value: Any) -> Any?
}

/// 属性名到转换器的绑定，供 `valueMapping()` 返回
public struct ZHHJSONValueMap {
    /// 目标模型属性名
    public let propertyName: String
    /// 负责该属性 JSON 值 ↔ 模型值的转换器
    public let transformer: any ZHHJSONTransforming

    /// 用属性 CodingKey 与转换器构造映射项
    public init(_ key: some CodingKey, _ transformer: any ZHHJSONTransforming) {
        self.propertyName = key.stringValue
        self.transformer = transformer
    }
}

/// 轻量值转换：用两个闭包做任意类型间的转换，省去自定义结构体
public struct ZHHJSONFastTransform<Object, JSON>: ZHHJSONTransforming {
    /// JSON 值 → 模型值的闭包
    private let from: (Any) -> Object?
    /// 模型值 → JSON 值的闭包
    private let to: (Object) -> JSON?

    /// 用两个闭包构造转换器
    public init(fromJSON: @escaping (Any) -> Object?, toJSON: @escaping (Object) -> JSON?) {
        self.from = fromJSON
        self.to = toJSON
    }

    public func fromJSON(_ value: Any) -> Any? { from(value) }
    public func toJSON(_ value: Any) -> Any? {
        guard let object = value as? Object else { return nil }
        return to(object)
    }
}

/// 日期转换器：支持秒/毫秒时间戳、ISO8601 与自定义格式
public struct ZHHJSONDateTransform: ZHHJSONTransforming {
    /// 日期解析/序列化的具体格式
    public enum Format {
        /// 秒级时间戳
        case secondsSince1970
        /// 毫秒级时间戳
        case millisecondsSince1970
        /// ISO8601 字符串
        case iso8601
        /// 自定义 DateFormatter
        case formatted(DateFormatter)
    }

    /// 当前转换器使用的格式
    private let format: Format

    /// 用指定格式构造日期转换器（默认秒级时间戳）
    public init(_ format: Format = .secondsSince1970) {
        self.format = format
    }

    /// 按指定格式把 JSON 节点转 Date；失败返回 nil
    public func fromJSON(_ value: Any) -> Any? {
        JSONTypeConverter.date(JSONNode.from(value), format: format)
    }

    /// 把 Date 按格式序列化；非 Date 入参返回 nil
    public func toJSON(_ value: Any) -> Any? {
        guard let date = value as? Date else { return nil }
        switch format {
        case .secondsSince1970:
            return date.timeIntervalSince1970
        case .millisecondsSince1970:
            return date.timeIntervalSince1970 * 1000
        case .iso8601:
            return ZHHJSONDateFormatters.iso8601String(from: date)
        case .formatted(let formatter):
            return formatter.string(from: date)
        }
    }
}

/// URL 转换器：解析前可自动补齐相对路径前缀
public struct ZHHJSONURLTransform: ZHHJSONTransforming {
    /// 相对路径缺失时自动补齐的前缀
    private let prefix: String

    /// 用前缀构造 URL 转换器（默认不补齐）
    public init(prefix: String = "") {
        self.prefix = prefix
    }

    /// 字符串转 URL；缺少前缀时先补齐再构造
    public func fromJSON(_ value: Any) -> Any? {
        guard var text = JSONTypeConverter.string(JSONNode.from(value)), !text.isEmpty else { return nil }
        if !prefix.isEmpty, !text.hasPrefix(prefix) { text = prefix + text }
        return URL(string: text)
    }

    /// URL 转绝对字符串；非 URL 入参返回 nil
    public func toJSON(_ value: Any) -> Any? {
        (value as? URL)?.absoluteString
    }
}

/// Data 转换器：JSON 字符串按 Base64 解析，编码时输出 Base64 字符串
public struct ZHHJSONDataTransform: ZHHJSONTransforming {
    public init() {}

    /// 值转 Data；已是 Data 直接返回，否则按 Base64 字符串解析
    public func fromJSON(_ value: Any) -> Any? {
        if let data = value as? Data { return data }
        guard let text = JSONTypeConverter.string(JSONNode.from(value)) else { return nil }
        return Data(base64Encoded: text)
    }

    /// Data 转 Base64 字符串；非 Data 入参返回 nil
    public func toJSON(_ value: Any) -> Any? {
        (value as? Data)?.base64EncodedString()
    }
}

/// 日期策略：解码/编码日期的统一方式
public enum ZHHJSONDateStrategy {
    /// 秒级时间戳
    case secondsSince1970
    /// 毫秒级时间戳
    case millisecondsSince1970
    /// ISO8601 字符串
    case iso8601
    /// 自定义 DateFormatter
    case formatted(DateFormatter)
    /// 自动识别秒/毫秒时间戳和常见日期字符串
    case automatic
}

extension JSONTypeConverter {
    /// 按具体格式把节点转 Date
    static func date(_ node: JSONNode, format: ZHHJSONDateTransform.Format) -> Date? {
        switch format {
        case .secondsSince1970:
            return double(node).map { Date(timeIntervalSince1970: $0) }
        case .millisecondsSince1970:
            return double(node).map { Date(timeIntervalSince1970: $0 / 1000) }
        case .iso8601:
            guard let text = string(node) else { return nil }
            return ZHHJSONDateFormatters.parse(text)?.date
        case .formatted(let formatter):
            guard let text = string(node) else { return nil }
            return formatter.date(from: text)
        }
    }

    /// 按策略把节点转 Date；automatic 走自动识别
    static func date(_ node: JSONNode, strategy: ZHHJSONDateStrategy) -> Date? {
        switch strategy {
        case .secondsSince1970:
            return date(node, format: .secondsSince1970)
        case .millisecondsSince1970:
            return date(node, format: .millisecondsSince1970)
        case .iso8601:
            return date(node, format: .iso8601)
        case .formatted(let formatter):
            return date(node, format: .formatted(formatter))
        case .automatic:
            return ZHHJSONDateParser.parse(node)?.date
        }
    }
}
