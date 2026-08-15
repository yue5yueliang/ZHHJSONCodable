//
//  ZHHJSONIgnored.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  跳过解码，保留 init() 里的初始值。
//

import Foundation

/// 标记协议：用于识别被忽略字段，供显式编码时调用
protocol ZHHJSONIgnoredMarker {
    func encodeIgnoredValue(to encoder: Encoder) throws
}

/// 忽略包装器：跳过解码，保留 `init()` 里的初始值
@propertyWrapper
public struct ZHHJSONIgnored<Value: Codable>: Codable, ZHHJSONIgnoredMarker {
    public var wrappedValue: Value

    /// 用初始值构造包装器
    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    /// 从解码器构造；默认回落初始值，显式开启时才真正解码
    public init(from decoder: Decoder) throws {
        // 显式开启忽略字段解码时，正常解码
        if let impl = decoder as? FlexibleDecoderImpl, impl.decodeIgnoredValues {
            wrappedValue = try impl.decodeValue(Value.self)
            return
        }
        // 否则回落零值 / 模型 init() 初始值
        if let value = JSONDefaultValue.primitive(Value.self) {
            wrappedValue = value
            return
        }
        if let modelType = Value.self as? any ZHHJSONCodable.Type, let value = modelType.init() as? Value {
            wrappedValue = value
            return
        }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "ZHHJSONIgnored 无法构造默认值"))
    }

    /// 默认不编码输出（空实现）
    public func encode(to encoder: Encoder) throws {}

    /// 显式输出忽略字段时调用，把值真正编码
    func encodeIgnoredValue(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}
