//
//  FlexibleKeyedContainer.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import Foundation

/// keyed 容器：按 key 取字段，缺值/类型不匹配时回落默认值，而非抛错
struct FlexibleKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: FlexibleDecoderImpl
    let object: [String: JSONNode]
    var codingPath: [CodingKey] { decoder.codingPath }

    /// 当前对象里所有可构造成 Key 的字段名
    var allKeys: [Key] {
        object.keys.compactMap { Key(stringValue: $0) }
    }

    /// 字段是否存在
    func contains(_ key: Key) -> Bool {
        resolvedNode(for: key) != nil
    }

    /// 字段缺失或值为 null 都视为 nil
    func decodeNil(forKey key: Key) throws -> Bool {
        guard let node = resolvedNode(for: key) else { return true }
        if case .null = node { return true }
        return false
    }

    /// 以下标量解码：转换失败时回落零值
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { fallback(type, key: key, convert: JSONTypeConverter.bool) ?? false }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { fallback(type, key: key, convert: JSONTypeConverter.string) ?? "" }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { fallback(type, key: key, convert: JSONTypeConverter.double) ?? 0 }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { fallback(type, key: key, convert: JSONTypeConverter.float) ?? 0 }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { fallback(type, key: key, convert: JSONTypeConverter.int) ?? 0 }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { fallback(type, key: key, convert: JSONTypeConverter.int8) ?? 0 }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { fallback(type, key: key, convert: JSONTypeConverter.int16) ?? 0 }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { fallback(type, key: key, convert: JSONTypeConverter.int32) ?? 0 }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { fallback(type, key: key, convert: JSONTypeConverter.int64) ?? 0 }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { fallback(type, key: key, convert: JSONTypeConverter.uint) ?? 0 }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { fallback(type, key: key, convert: JSONTypeConverter.uint8) ?? 0 }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { fallback(type, key: key, convert: JSONTypeConverter.uint16) ?? 0 }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { fallback(type, key: key, convert: JSONTypeConverter.uint32) ?? 0 }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { fallback(type, key: key, convert: JSONTypeConverter.uint64) ?? 0 }

    /// 通用解码：依次处理忽略字段、展平字段、值转换、标量转换，最后回落默认值兜底
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        // 被 @ZHHJSONIgnored 标记：默认跳过并保留初始值，显式开启时才解码
        if type is ZHHJSONIgnoredMarker.Type {
            if decoder.decodeIgnoredValues {
                let node = resolvedNode(for: key) ?? .null
                return try decodeNested(type, key: key, node: node)
            }
            if let ignored = decoder.defaultValue(type, property: key.stringValue) { return ignored }
            return try decodeNested(type, key: key, node: .null)
        }
        // 被 @ZHHJSONFlat 标记：把整个对象当参数解码，不取子字段
        if type is ZHHJSONFlatMarker.Type {
            return try decoder.child(node: .object(object), key: key, type: type).decodeValue(type)
        }
        // 优先走属性级值转换器
        if let transformed = transformedValue(type, key: key) { return transformed }
        // 再走标量转换
        if let converted = convertIfPrimitive(type, key: key) { return converted }
        let node = resolvedNode(for: key) ?? .null
        if isNull(node), let fallback = decoder.defaultValue(type, property: key.stringValue) {
            return fallback
        }
        // 期望数组/字典但实际不是时，直接回落默认值
        if type is any FlexibleArrayDecoding.Type, node.resolvedArray() == nil {
            if let fallback = decoder.defaultValue(type, property: key.stringValue) { return fallback }
            return try decodeNested(type, key: key, node: node)
        }
        if type is any FlexibleDictionaryDecoding.Type, node.resolvedObject() == nil {
            if let fallback = decoder.defaultValue(type, property: key.stringValue) { return fallback }
            return try decodeNested(type, key: key, node: node)
        }
        do {
            // null 转空对象，让嵌套模型走 init() 初始值
            return try decodeNested(type, key: key, node: isNull(node) ? .object([:]) : node)
        } catch {
            // 解码失败但有默认值可回落时吞掉错误，记录日志
            if let fallback = decoder.defaultValue(type, property: key.stringValue) {
                decoder.logSession?.record(
                    path: decoder.codingPath + [key],
                    expected: "\(type)",
                    actual: node.typeName,
                    action: "已回落初始值"
                )
                return fallback
            }
            throw error
        }
    }

    /// 以下可选标量解码：缺失/null/空串或转换失败时回落默认值
    func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? { optional(type, key: key, convert: JSONTypeConverter.bool) }
    func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? { optional(type, key: key, convert: JSONTypeConverter.string) }
    func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? { optional(type, key: key, convert: JSONTypeConverter.double) }
    func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? { optional(type, key: key, convert: JSONTypeConverter.float) }
    func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? { optional(type, key: key, convert: JSONTypeConverter.int) }
    func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        optional(type, key: key, convert: JSONTypeConverter.int8)
    }
    func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        optional(type, key: key, convert: JSONTypeConverter.int16)
    }
    func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        optional(type, key: key, convert: JSONTypeConverter.int32)
    }
    func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? { optional(type, key: key, convert: JSONTypeConverter.int64) }
    func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        optional(type, key: key, convert: JSONTypeConverter.uint)
    }
    func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        optional(type, key: key, convert: JSONTypeConverter.uint8)
    }
    func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        optional(type, key: key, convert: JSONTypeConverter.uint16)
    }
    func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        optional(type, key: key, convert: JSONTypeConverter.uint32)
    }
    func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? { optional(type, key: key, convert: JSONTypeConverter.uint64) }

    /// 可选字段解码：缺失/null/空串时回落默认值，成功失败都不抛错
    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        guard let node = resolvedNode(for: key), !isMissingOptional(node) else {
            return decoder.defaultValue(type, property: key.stringValue)
        }
        if let transformed = transformedValue(type, key: key) { return transformed }
        if let converted = decoder.convertPrimitive(type, node: node) { return converted }
        let child = decoder.child(node: node, key: key, type: type)
        return (try? child.decodeValue(type)) ?? decoder.defaultValue(type, property: key.stringValue)
    }

    /// 嵌套对象解码容器；缺字段时用空对象
    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        try decoder.child(node: resolvedNode(for: key) ?? .object([:]), key: key, type: Any.self).container(keyedBy: type)
    }

    /// 嵌套数组解码容器；缺字段时用空数组
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try decoder.child(node: resolvedNode(for: key) ?? .array([]), key: key, type: Any.self).unkeyedContainer()
    }

    /// 父类解码器，直接复用当前解码器
    func superDecoder() throws -> Decoder { decoder }

    /// 指定 key 的父类解码器
    func superDecoder(forKey key: Key) throws -> Decoder {
        decoder.child(node: resolvedNode(for: key) ?? .null, key: key, type: Any.self)
    }

    /// 用 key 解析器取字段节点（含候选 key、蛇形命名）
    private func resolvedNode(for key: Key) -> JSONNode? {
        JSONKeyResolver.resolvedNode(
            for: key.stringValue,
            object: object,
            maps: decoder.keyMaps,
            strategy: decoder.keyStrategy
        )
    }

    /// 判断节点是否为 null
    private func isNull(_ node: JSONNode) -> Bool {
        if case .null = node { return true }
        return false
    }

    /// 取节点转标量；缺失/null 或转换失败返回 nil
    private func primitive<T>(_ type: T.Type, key: Key, convert: (JSONNode) -> T?) -> T? {
        guard let node = resolvedNode(for: key), !isNull(node) else { return nil }
        if let value = convert(node) { return value }
        decoder.logSession?.record(
            path: decoder.codingPath + [key],
            expected: "\(type)",
            actual: node.typeName,
            action: "已回落初始值"
        )
        return nil
    }

    /// 标量转换失败时回落默认值
    private func fallback<T>(_ type: T.Type, key: Key, convert: (JSONNode) -> T?) -> T? {
        if let value = primitive(type, key: key, convert: convert) { return value }
        return decoder.defaultValue(type, property: key.stringValue)
    }

    /// 可选标量：缺失/null/空串时回落默认值
    private func optional<T>(_ type: T.Type, key: Key, convert: (JSONNode) -> T?) -> T? {
        guard let node = resolvedNode(for: key), !isMissingOptional(node) else {
            return decoder.defaultValue(type, property: key.stringValue)
        }
        return convert(node) ?? decoder.defaultValue(type, property: key.stringValue)
    }

    /// 标量类型走统一转换，非标量返回 nil
    private func convertIfPrimitive<T: Decodable>(_ type: T.Type, key: Key) -> T? {
        guard let node = resolvedNode(for: key), !isNull(node) else { return nil }
        return decoder.convertPrimitive(type, node: node)
    }

    /// 命中 valueMapping 时用转换器取值
    private func transformedValue<T>(_ type: T.Type, key: Key) -> T? {
        guard let transformer = decoder.valueMaps[key.stringValue],
              let node = resolvedNode(for: key), !isNull(node),
              let value = transformer.fromJSON(node.toFoundation()) as? T else { return nil }
        return value
    }

    /// 判断可选字段是否应视为缺失：null，或开启 emptyStringAsNil 时的空串
    private func isMissingOptional(_ node: JSONNode) -> Bool {
        if isNull(node) { return true }
        guard decoder.emptyStringAsNil, case .string(let value) = node else { return false }
        return value.isEmpty
    }

    /// 用子解码器解嵌套值
    private func decodeNested<T: Decodable>(_ type: T.Type, key: Key, node: JSONNode) throws -> T {
        try decoder.child(node: node, key: key, type: type).decodeValue(type)
    }
}
