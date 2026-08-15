//
//  KeyedDecodingContainer+Flexible.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  兼容层：给原生 JSONDecoder + 手写 init(from:) 用。主路径请走 FlexibleJSONDecoder。
//  转换统一走 JSONTypeConverter，避免和主 Decoder 两套规则。
//

import CoreGraphics
import Foundation

/// 兼容层扩展：给原生 `JSONDecoder` + 手写 `init(from:)` 提供柔性解码
///
/// 主路径请走 `FlexibleJSONDecoder`；此处统一复用 `JSONTypeConverter`，避免两套转换规则
public extension KeyedDecodingContainer {

    /// 按自动策略柔性解码可选值
    func decodeFlexibleIfPresent<T>(_ type: T.Type, forKey key: Key) -> T? {
        convertKnown(type, key: key, dateStrategy: .automatic)
    }

    /// 柔性解码，失败回落给定默认值
    func decodeFlexible<T>(_ type: T.Type, forKey key: Key, default defaultValue: T) -> T {
        decodeFlexibleIfPresent(type, forKey: key) ?? defaultValue
    }

    /// 按指定日期策略柔性解码日期
    func decodeFlexibleIfPresent(_ type: Date.Type, forKey key: Key, strategy: ZHHJSONDateStrategy) -> Date? {
        convertKnown(type, key: key, dateStrategy: strategy)
    }

    /// 按指定日期策略柔性解码日期，失败回落默认值
    func decodeFlexible(_ type: Date.Type, forKey key: Key, strategy: ZHHJSONDateStrategy, default defaultValue: Date) -> Date {
        decodeFlexibleIfPresent(type, forKey: key, strategy: strategy) ?? defaultValue
    }
}

private extension KeyedDecodingContainer {

    /// 取字段节点做柔性转换；失败时按开关输出日志
    func convertKnown<T>(_ type: T.Type, key: Key, dateStrategy: ZHHJSONDateStrategy) -> T? {
        guard shouldDecodeFlexible(forKey: key), let node = flexibleNode(forKey: key) else { return nil }
        if let value = convertedValue(type, node: node, dateStrategy: dateStrategy) { return value }
        guard ZHHJSONConfiguration.isLogEnabled else { return nil }
        ZHHJSONConfiguration.emit("ZHHJSONCodable: 柔性解码失败 | key=\(key.stringValue) 期望=\(type)")
        return nil
    }

    /// 把节点按目标类型做柔性转换；不在范围内的类型返回 nil
    func convertedValue<T>(_ : T.Type, node: JSONNode, dateStrategy: ZHHJSONDateStrategy) -> T? {
        if T.self == Date.self { return JSONTypeConverter.date(node, strategy: dateStrategy) as? T }
        if T.self == Data.self {
            return JSONTypeConverter.string(node).flatMap { Data(base64Encoded: $0) } as? T
        }
        if T.self == URL.self, let text = JSONTypeConverter.string(node), let url = URL(string: text) {
            return url as? T
        }
        if T.self == Decimal.self { return JSONTypeConverter.decimal(node) as? T }
        if T.self == CGFloat.self, let value = JSONTypeConverter.double(node) { return CGFloat(value) as? T }
        if T.self == Bool.self { return JSONTypeConverter.bool(node) as? T }
        if T.self == String.self { return JSONTypeConverter.string(node) as? T }
        if T.self == Double.self { return JSONTypeConverter.double(node) as? T }
        if T.self == Float.self { return JSONTypeConverter.float(node) as? T }
        if T.self == Int.self { return JSONTypeConverter.int(node) as? T }
        if T.self == Int8.self { return JSONTypeConverter.int8(node) as? T }
        if T.self == Int16.self { return JSONTypeConverter.int16(node) as? T }
        if T.self == Int32.self { return JSONTypeConverter.int32(node) as? T }
        if T.self == Int64.self { return JSONTypeConverter.int64(node) as? T }
        if T.self == UInt.self { return JSONTypeConverter.uint(node) as? T }
        if T.self == UInt8.self { return JSONTypeConverter.uint8(node) as? T }
        if T.self == UInt16.self { return JSONTypeConverter.uint16(node) as? T }
        if T.self == UInt32.self { return JSONTypeConverter.uint32(node) as? T }
        if T.self == UInt64.self { return JSONTypeConverter.uint64(node) as? T }
        return nil
    }

    /// 用原生容器把字段值按 Bool/Int/Double/String 顺序包成 JSONNode
    func flexibleNode(forKey key: Key) -> JSONNode? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return .bool(value) }
        if let value = try? decodeIfPresent(Int64.self, forKey: key) { return .number(NSNumber(value: value)) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return .number(NSNumber(value: value)) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return .string(value) }
        return nil
    }

    /// 字段存在且非 null 时才做柔性解码
    func shouldDecodeFlexible(forKey key: Key) -> Bool {
        guard contains(key) else { return false }
        if (try? decodeNil(forKey: key)) == true { return false }
        return true
    }
}
