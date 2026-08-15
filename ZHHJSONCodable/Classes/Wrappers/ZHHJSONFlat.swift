//
//  ZHHJSONFlat.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  把当前层 JSON 展平解码进嵌套模型。
//

import Foundation

/// 标记协议：用于识别展平字段的类型
protocol ZHHJSONFlatMarker {
    static var wrappedType: Any.Type { get }
}

/// 展平包装器：把当前层 JSON 直接解码进嵌套模型，不取子字段
@propertyWrapper
public struct ZHHJSONFlat<Value: Codable>: Codable, ZHHJSONFlatMarker {
    public var wrappedValue: Value

    /// 用初始值构造包装器
    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    /// 从解码器构造；主路径用当前节点直接解码实现展平
    public init(from decoder: Decoder) throws {
        // 主路径：用当前节点直接解码，实现「展平」
        if let impl = decoder as? FlexibleDecoderImpl {
            wrappedValue = try impl.decodeValue(Value.self)
            return
        }
        wrappedValue = try Value(from: decoder)
    }

    /// 编码时直接透传内部值
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }

    static var wrappedType: Any.Type { Value.self }
}
