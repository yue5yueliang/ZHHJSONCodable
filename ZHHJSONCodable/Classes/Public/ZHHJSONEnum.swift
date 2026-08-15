//
//  ZHHJSONEnum.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  非法枚举值回落到第一个 case，不中断解析。
//

import Foundation

/// 柔性枚举协议：非法 rawValue 回落到第一个 case，而非抛错中断
public protocol ZHHJSONEnum: RawRepresentable, CaseIterable, Codable where RawValue: Codable {}

extension ZHHJSONEnum {
    /// 兜底 case：取声明顺序第一个，作为非法值的回落目标
    static var fallbackCase: Self {
        allCases[allCases.startIndex]
    }

    /// 从节点柔性解码：rawValue 命中则返回对应 case，否则回落第一个 case
    static func decodeFlexibleCase(from node: JSONNode) -> Self {
        if let value = rawValue(from: node) { return value }
        return fallbackCase
    }

    /// 按 RawValue 的具体整数/字符串类型取对应转换器，命中则构造 case，否则返回 nil
    private static func rawValue(from node: JSONNode) -> Self? {
        if RawValue.self == String.self, let text = JSONTypeConverter.string(node) {
            return Self(rawValue: text as! RawValue)
        }
        if RawValue.self == Int.self, let number = JSONTypeConverter.int(node) {
            return Self(rawValue: number as! RawValue)
        }
        if RawValue.self == Int8.self, let number = JSONTypeConverter.int8(node) {
            return Self(rawValue: number as! RawValue)
        }
        if RawValue.self == Int16.self, let number = JSONTypeConverter.int16(node) {
            return Self(rawValue: number as! RawValue)
        }
        if RawValue.self == Int32.self, let number = JSONTypeConverter.int32(node) {
            return Self(rawValue: number as! RawValue)
        }
        if RawValue.self == Int64.self, let number = JSONTypeConverter.int64(node) {
            return Self(rawValue: number as! RawValue)
        }
        if RawValue.self == UInt.self, let number = JSONTypeConverter.uint(node) {
            return Self(rawValue: number as! RawValue)
        }
        if RawValue.self == UInt8.self, let number = JSONTypeConverter.uint8(node) {
            return Self(rawValue: number as! RawValue)
        }
        if RawValue.self == UInt16.self, let number = JSONTypeConverter.uint16(node) {
            return Self(rawValue: number as! RawValue)
        }
        if RawValue.self == UInt32.self, let number = JSONTypeConverter.uint32(node) {
            return Self(rawValue: number as! RawValue)
        }
        if RawValue.self == UInt64.self, let number = JSONTypeConverter.uint64(node) {
            return Self(rawValue: number as! RawValue)
        }
        return nil
    }
}

/// 供解码器调用的擦除类型入口：按具体枚举类型分发
func decodeFlexibleEnum(_ type: any ZHHJSONEnum.Type, from node: JSONNode) -> Any {
    decodeOpenedEnum(type, from: node)
}

/// 把擦除后的类型重新打开成具体 `E`，再走对应解码
private func decodeOpenedEnum<E: ZHHJSONEnum>(_ type: E.Type, from node: JSONNode) -> Any {
    E.decodeFlexibleCase(from: node)
}
