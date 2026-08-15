//
//  FlexibleUnkeyedContainer.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import Foundation

/// unkeyed 容器：按顺序消费数组元素，逐元素类型转换
struct FlexibleUnkeyedContainer: UnkeyedDecodingContainer {
    let decoder: FlexibleDecoderImpl
    let array: [JSONNode]
    var codingPath: [CodingKey] { decoder.codingPath }
    var count: Int? { array.count }
    var isAtEnd: Bool { currentIndex >= array.count }
    var currentIndex = 0

    /// 当前元素为 null 时消费并返回 true；越界视为 null
    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else { return true }
        if case .null = array[currentIndex] {
            currentIndex += 1
            return true
        }
        return false
    }

    /// 以下标量解码：越界抛 valueNotFound，转换失败抛 typeMismatch
    mutating func decode(_ type: Bool.Type) throws -> Bool { try nextRequired(type, convert: JSONTypeConverter.bool) }
    mutating func decode(_ type: String.Type) throws -> String { try nextRequired(type, convert: JSONTypeConverter.string) }
    mutating func decode(_ type: Double.Type) throws -> Double { try nextRequired(type, convert: JSONTypeConverter.double) }
    mutating func decode(_ type: Float.Type) throws -> Float { try nextRequired(type, convert: JSONTypeConverter.float) }
    mutating func decode(_ type: Int.Type) throws -> Int { try nextRequired(type, convert: JSONTypeConverter.int) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { try nextRequired(type, convert: JSONTypeConverter.int8) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { try nextRequired(type, convert: JSONTypeConverter.int16) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { try nextRequired(type, convert: JSONTypeConverter.int32) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { try nextRequired(type, convert: JSONTypeConverter.int64) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { try nextRequired(type, convert: JSONTypeConverter.uint) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try nextRequired(type, convert: JSONTypeConverter.uint8) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try nextRequired(type, convert: JSONTypeConverter.uint16) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try nextRequired(type, convert: JSONTypeConverter.uint32) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try nextRequired(type, convert: JSONTypeConverter.uint64) }

    /// 通用元素解码：无法匹配时抛 typeMismatch（数组元素不做静默回落）
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let node = nextNode() ?? .null
        let key = AnyCodingKey(intValue: currentIndex - 1)
        guard decoder.canDecode(type, from: node) else {
            throw DecodingError.typeMismatch(type, .init(codingPath: codingPath + [key], debugDescription: "数组元素无法转为 \(type)"))
        }
        return try decoder.child(node: node, key: key, type: type).decodeValue(type)
    }

    /// 嵌套对象解码容器；越界时用空对象
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        let node = nextNode() ?? .object([:])
        return try decoder.child(node: node, key: AnyCodingKey(intValue: currentIndex - 1), type: Any.self).container(keyedBy: type)
    }

    /// 嵌套数组解码容器；越界时用空数组
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let node = nextNode() ?? .array([])
        return try decoder.child(node: node, key: AnyCodingKey(intValue: currentIndex - 1), type: Any.self).unkeyedContainer()
    }

    /// 父类解码器；越界时用 null 节点
    mutating func superDecoder() throws -> Decoder {
        decoder.child(node: nextNode() ?? .null, key: AnyCodingKey(intValue: currentIndex - 1), type: Any.self)
    }

    /// 取当前元素并推进游标；越界返回 nil
    private mutating func nextNode() -> JSONNode? {
        guard !isAtEnd else { return nil }
        defer { currentIndex += 1 }
        return array[currentIndex]
    }

    /// 标量元素解码：越界抛 valueNotFound，转换失败抛 typeMismatch
    private mutating func nextRequired<T>(_ type: T.Type, convert: (JSONNode) -> T?) throws -> T {
        let key = AnyCodingKey(intValue: currentIndex)
        guard let node = nextNode() else {
            throw DecodingError.valueNotFound(type, .init(codingPath: codingPath + [key], debugDescription: "数组已结束"))
        }
        if let value = convert(node) { return value }
        decoder.logSession?.record(
            path: codingPath + [key],
            expected: "\(type)",
            actual: node.typeName,
            action: "类型不匹配"
        )
        throw DecodingError.typeMismatch(type, .init(codingPath: codingPath + [key], debugDescription: "无法转为 \(type)"))
    }
}
