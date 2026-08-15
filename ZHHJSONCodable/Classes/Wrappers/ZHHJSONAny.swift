//
//  ZHHJSONAny.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  承接原生 Codable 不支持的 Any / 字典 / 数组。
//

import Foundation

/// 承接原生 Codable 不支持的 Any / 字典 / 数组值
@propertyWrapper
public struct ZHHJSONAny<Value>: Codable {
    public var wrappedValue: Value

    /// 用初始值构造包装器
    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    /// 从解码器构造；主路径直接转节点，原生路径仅支持 null
    public init(from decoder: Decoder) throws {
        // 主路径：直接取节点转 Foundation 对象再转 Value
        if let impl = decoder as? FlexibleDecoderImpl, let value = Self.cast(impl.node.toFoundation()) {
            wrappedValue = value
            return
        }
        // 原生路径：仅支持 null
        let container = try decoder.singleValueContainer()
        if container.decodeNil(), let value = Self.cast(NSNull()) {
            wrappedValue = value
            return
        }
        throw DecodingError.typeMismatch(
            Value.self,
            .init(codingPath: decoder.codingPath, debugDescription: "ZHHJSONAny 无法解码为 \(Value.self)")
        )
    }

    /// 编码：主路径直接写节点，原生路径退化为 null
    public func encode(to encoder: Encoder) throws {
        // 主路径：直接写入节点
        if let impl = encoder as? FlexibleEncoderImpl {
            impl.box.node = JSONNode.from(wrappedValue as Any)
            return
        }
        // 原生路径：退化为 null
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }

    /// 把任意值转成目标类型；NSNull 视为 Optional.none
    private static func cast(_ value: Any) -> Value? {
        if value is NSNull {
            return Optional<Any>.none as? Value
        }
        if let typed = value as? Value { return typed }
        if Value.self == Any.self { return value as? Value }
        return nil
    }
}
