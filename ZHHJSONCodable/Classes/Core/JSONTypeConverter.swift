//
//  JSONTypeConverter.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  把 JSON 节点转成基础类型；转不成返回 nil。
//

import CoreGraphics
import Foundation

/// 把 JSON 节点转成基础类型；转不成返回 nil，由解码方回落默认值
///
/// 核心策略：类型不匹配尽量转换（如字符串数字、布尔当 0/1），越界或 nan/inf 时返回 nil 而非截断
enum JSONTypeConverter {

    /// 布尔转换：数字非 0 为真；字符串识别 true/false/1/0/yes/no/y/n
    static func bool(_ node: JSONNode) -> Bool? {
        switch node {
        case .bool(let value):
            return value
        case .number(let number):
            return number.intValue != 0
        case .string(let text):
            let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "1", "yes", "y"].contains(lower) { return true }
            if ["false", "0", "no", "n"].contains(lower) { return false }
            return nil
        default:
            return nil
        }
    }

    /// 转 Int：先按 Int64 转，再精确降位，越界返回 nil
    static func int(_ node: JSONNode) -> Int? {
        int64(node).flatMap(Int.init(exactly:))
    }

    /// 转 Int64：数字/字符串/布尔（1/0）均可转换
    static func int64(_ node: JSONNode) -> Int64? {
        switch node {
        case .number(let number):
            return integer(number, as: Int64.self)
        case .string(let text):
            return integer(from: text, as: Int64.self)
        case .bool(let value):
            return value ? 1 : 0
        default:
            return nil
        }
    }

    /// 转 UInt64：数字/字符串/布尔（1/0）均可转换，负数返回 nil
    static func uint64(_ node: JSONNode) -> UInt64? {
        switch node {
        case .number(let number):
            return integer(number, as: UInt64.self)
        case .string(let text):
            return integer(from: text, as: UInt64.self)
        case .bool(let value):
            return value ? 1 : 0
        default:
            return nil
        }
    }

    /// 转 Double：nan/inf 一律返回 nil，避免污染下游
    static func double(_ node: JSONNode) -> Double? {
        switch node {
        case .number(let number):
            let value = number.doubleValue
            return value.isFinite ? value : nil
        case .string(let text):
            guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else { return nil }
            return value
        case .bool(let value):
            return value ? 1 : 0
        default:
            return nil
        }
    }

    /// 转 Float：先转 Double 再降精度，非有限值返回 nil
    static func float(_ node: JSONNode) -> Float? {
        guard let value = double(node) else { return nil }
        let converted = Float(value)
        return converted.isFinite ? converted : nil
    }

    /// 转 Decimal：优先走字符串精确解析，回落到 Double
    static func decimal(_ node: JSONNode) -> Decimal? {
        if let text = string(node), let value = Decimal(string: text) { return value }
        if let value = double(node) { return Decimal(value) }
        return nil
    }

    /// 转 String：数字/布尔也转成字符串表示
    static func string(_ node: JSONNode) -> String? {
        switch node {
        case .string(let value):
            return value
        case .number(let number):
            return number.stringValue
        case .bool(let value):
            return value ? "true" : "false"
        default:
            return nil
        }
    }

    /// 以下小整数类型统一从 Int64/UInt64 精确降位，越界返回 nil
    static func int8(_ node: JSONNode) -> Int8? { int64(node).flatMap(Int8.init(exactly:)) }
    static func int16(_ node: JSONNode) -> Int16? { int64(node).flatMap(Int16.init(exactly:)) }
    static func int32(_ node: JSONNode) -> Int32? { int64(node).flatMap(Int32.init(exactly:)) }
    static func uint(_ node: JSONNode) -> UInt? { uint64(node).flatMap(UInt.init(exactly:)) }
    static func uint8(_ node: JSONNode) -> UInt8? { uint64(node).flatMap(UInt8.init(exactly:)) }
    static func uint16(_ node: JSONNode) -> UInt16? { uint64(node).flatMap(UInt16.init(exactly:)) }
    static func uint32(_ node: JSONNode) -> UInt32? { uint64(node).flatMap(UInt32.init(exactly:)) }

    /// 从 NSNumber 精确转整数；浮点类型走 Double 路径，负数转无符号返回 nil
    private static func integer<T: FixedWidthInteger>(_ number: NSNumber, as _: T.Type) -> T? {
        if CFNumberIsFloatType(number) {
            return integer(fromDouble: number.doubleValue, as: T.self)
        }
        if T.isSigned {
            return T(exactly: number.int64Value)
        }
        if number.compare(0) == .orderedAscending { return nil }
        return T(exactly: number.uint64Value)
    }

    /// 从字符串转整数：先精确解析，失败再走 Double 兜底
    private static func integer<T: FixedWidthInteger>(from text: String, as _: T.Type) -> T? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = T(trimmed) { return value }
        guard let value = Double(trimmed) else { return nil }
        return integer(fromDouble: value, as: T.self)
    }

    /// 从 Double 精确转整数：越界或非有限值返回 nil，不截断
    private static func integer<T: FixedWidthInteger>(fromDouble value: Double, as _: T.Type) -> T? {
        guard value.isFinite else { return nil }
        if T.isSigned {
            guard value >= Double(Int64.min), value <= Double(Int64.max) else { return nil }
            return T(exactly: Int64(value))
        }
        guard value >= 0, value <= Double(UInt64.max) else { return nil }
        return T(exactly: UInt64(value))
    }
}

/// 按类型给出「零值」默认值，供解码缺失标量时回落
enum JSONDefaultValue {

    /// 返回指定标量类型的零值，未列出的类型返回 nil
    static func primitive<T>(_ type: T.Type) -> T? {
        switch type {
        case is Bool.Type: return false as? T
        case is String.Type: return "" as? T
        case is Int.Type: return 0 as? T
        case is Int8.Type: return 0 as? T
        case is Int16.Type: return 0 as? T
        case is Int32.Type: return 0 as? T
        case is Int64.Type: return 0 as? T
        case is UInt.Type: return 0 as? T
        case is UInt8.Type: return 0 as? T
        case is UInt16.Type: return 0 as? T
        case is UInt32.Type: return 0 as? T
        case is UInt64.Type: return 0 as? T
        case is Float.Type: return 0 as? T
        case is Double.Type: return 0 as? T
        case is CGFloat.Type: return CGFloat(0) as? T
        case is Decimal.Type: return Decimal(0) as? T
        case is Date.Type: return Date(timeIntervalSince1970: 0) as? T
        default: return nil
        }
    }
}

/// 通用 CodingKey 实现：供数组下标、动态 key 场景使用
struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
