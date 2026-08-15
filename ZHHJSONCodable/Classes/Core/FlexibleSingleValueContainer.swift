//
//  FlexibleSingleValueContainer.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import Foundation

/// 单值容器：对标量节点做类型转换
struct FlexibleSingleValueContainer: SingleValueDecodingContainer {
    let decoder: FlexibleDecoderImpl
    let node: JSONNode
    var codingPath: [CodingKey] { decoder.codingPath }

    /// 节点为 null 时返回 true
    func decodeNil() -> Bool {
        if case .null = node { return true }
        return false
    }

    /// 以下标量解码：转换失败抛 typeMismatch
    func decode(_ type: Bool.Type) throws -> Bool { try required(type, convert: JSONTypeConverter.bool) }
    func decode(_ type: String.Type) throws -> String { try required(type, convert: JSONTypeConverter.string) }
    func decode(_ type: Double.Type) throws -> Double { try required(type, convert: JSONTypeConverter.double) }
    func decode(_ type: Float.Type) throws -> Float { try required(type, convert: JSONTypeConverter.float) }
    func decode(_ type: Int.Type) throws -> Int { try required(type, convert: JSONTypeConverter.int) }
    func decode(_ type: Int8.Type) throws -> Int8 { try required(type, convert: JSONTypeConverter.int8) }
    func decode(_ type: Int16.Type) throws -> Int16 { try required(type, convert: JSONTypeConverter.int16) }
    func decode(_ type: Int32.Type) throws -> Int32 { try required(type, convert: JSONTypeConverter.int32) }
    func decode(_ type: Int64.Type) throws -> Int64 { try required(type, convert: JSONTypeConverter.int64) }
    func decode(_ type: UInt.Type) throws -> UInt { try required(type, convert: JSONTypeConverter.uint) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try required(type, convert: JSONTypeConverter.uint8) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try required(type, convert: JSONTypeConverter.uint16) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try required(type, convert: JSONTypeConverter.uint32) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try required(type, convert: JSONTypeConverter.uint64) }

    /// 通用解码：直接交给解码器按类型分派
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try decoder.decodeValue(type)
    }

    /// 标量转换；失败抛 typeMismatch
    private func required<T>(_ type: T.Type, convert: (JSONNode) -> T?) throws -> T {
        if let value = convert(node) { return value }
        throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "无法转为 \(type)"))
    }
}
