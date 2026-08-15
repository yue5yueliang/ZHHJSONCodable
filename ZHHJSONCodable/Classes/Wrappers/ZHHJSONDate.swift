//
//  ZHHJSONDate.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  自动识别时间戳和常见日期字符串。
//

import Foundation

/// 日期包装器：自动识别时间戳（秒/毫秒）和常见日期字符串
@propertyWrapper
public struct ZHHJSONDate: Codable {
    public var wrappedValue: Date?
    /// 编码时使用的日期策略，解码时会被自动识别的策略回填
    public var encodeStrategy: ZHHJSONDateStrategy

    /// 用初始值与编码策略构造包装器
    public init(wrappedValue: Date?, encodeStrategy: ZHHJSONDateStrategy = .automatic) {
        self.wrappedValue = wrappedValue
        self.encodeStrategy = encodeStrategy
    }

    /// 从解码器构造；主路径自动识别，原生路径逐类型尝试
    public init(from decoder: Decoder) throws {
        // 主路径：直接从节点解析并记录识别出的策略
        if let impl = decoder as? FlexibleDecoderImpl, let parsed = ZHHJSONDateParser.parse(impl.node) {
            wrappedValue = parsed.date
            encodeStrategy = parsed.strategy
            return
        }
        // 原生路径：逐类型尝试 String / Double
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            wrappedValue = nil
            encodeStrategy = .automatic
            return
        }
        if let text = try? container.decode(String.self),
           let parsed = ZHHJSONDateParser.parse(.string(text)) {
            wrappedValue = parsed.date
            encodeStrategy = parsed.strategy
            return
        }
        if let value = try? container.decode(Double.self),
           let parsed = ZHHJSONDateParser.parse(.number(NSNumber(value: value))) {
            wrappedValue = parsed.date
            encodeStrategy = parsed.strategy
            return
        }
        wrappedValue = nil
        encodeStrategy = .automatic
    }

    /// 按策略编码日期；nil 时编码 null
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        guard let date = wrappedValue else {
            try container.encodeNil()
            return
        }
        // 按策略转成字符串或数字再编码
        if let json = ZHHJSONDateTransform(encodeFormat(encodeStrategy)).toJSON(date) {
            if let text = json as? String {
                try container.encode(text)
            } else if let number = json as? Double {
                try container.encode(number)
            } else if let number = json as? NSNumber {
                try container.encode(number.doubleValue)
            } else {
                try container.encode(date.timeIntervalSince1970)
            }
        }
    }

    /// 策略转编码格式；automatic 编码时按秒级时间戳
    private func encodeFormat(_ strategy: ZHHJSONDateStrategy) -> ZHHJSONDateTransform.Format {
        switch strategy {
        case .secondsSince1970, .automatic: return .secondsSince1970
        case .millisecondsSince1970: return .millisecondsSince1970
        case .iso8601: return .iso8601
        case .formatted(let formatter): return .formatted(formatter)
        }
    }
}

/// 日期解析：按时间戳/常见字符串格式识别
enum ZHHJSONDateParser {
    /// 常见日期字符串格式，按顺序尝试
    static let knownFormats = [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd",
        "yyyy/MM/dd",
        "MM/dd/yyyy",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    ]

    /// 按时间戳量级或常见字符串格式解析日期
    static func parse(_ node: JSONNode) -> (date: Date, strategy: ZHHJSONDateStrategy)? {
        // 数字按量级区分秒/毫秒时间戳
        if let number = JSONTypeConverter.double(node) {
            if number > 1_000_000_000_000 {
                return (Date(timeIntervalSince1970: number / 1000), .millisecondsSince1970)
            }
            return (Date(timeIntervalSince1970: number), .secondsSince1970)
        }
        guard let text = JSONTypeConverter.string(node), !text.isEmpty else { return nil }
        return ZHHJSONDateFormatters.parse(text)
    }
}

/// 日期格式器缓存：线程安全地复用 DateFormatter，避免反复创建开销
enum ZHHJSONDateFormatters {
    static let iso8601 = ISO8601DateFormatter()

    private static let lock = NSLock()
    private static var named: [String: DateFormatter] = [:]

    /// 按已知格式顺序尝试解析字符串，命中即返回
    static func parse(_ text: String) -> (date: Date, strategy: ZHHJSONDateStrategy)? {
        lock.lock()
        defer { lock.unlock() }
        for format in ZHHJSONDateParser.knownFormats {
            if let date = formatter(format).date(from: text) {
                return (date, .formatted(formatter(format)))
            }
        }
        if let date = iso8601.date(from: text) {
            return (date, .iso8601)
        }
        return nil
    }

    /// 把日期格式化为 ISO8601 字符串
    static func iso8601String(from date: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        return iso8601.string(from: date)
    }

    /// 取指定格式的缓存 formatter；固定 POSIX locale，避免用户月份名等影响解析
    private static func formatter(_ format: String) -> DateFormatter {
        if let cached = named[format] { return cached }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        named[format] = formatter
        return formatter
    }
}
