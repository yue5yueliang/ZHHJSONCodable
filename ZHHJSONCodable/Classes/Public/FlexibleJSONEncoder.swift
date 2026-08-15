//
//  FlexibleJSONEncoder.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import Foundation

/// 柔性编码器：把对象编码为 Data / 原生对象 / JSONNode
public final class FlexibleJSONEncoder {
    /// JSON key 命名策略（默认原样使用）
    public var keyStrategy: ZHHJSONKeyStrategy = .useDefaultKeys
    /// 日期序列化策略（默认按秒级时间戳）
    public var dateStrategy: ZHHJSONDateStrategy = .secondsSince1970
    /// 是否把属性名按 `keyMapping()` 映射后再输出（默认开启）
    public var useMappedKeys = true
    /// 输出 JSON 是否带缩进换行（默认紧凑）
    public var prettyPrinted = false
    /// 透传给自定义 `encode(to:)` 的上下文信息
    public var userInfo: [CodingUserInfoKey: Any] = [:]
    /// 内部开关：是否把被 `@ZHHJSONIgnored` 标记的字段也编码输出（默认不）
    var includeIgnoredValues = false

    public init() {}

    /// 用编码配置初始化
    public convenience init(options: ZHHJSONEncodeOptions) {
        self.init()
        keyStrategy = options.keyStrategy
        dateStrategy = options.dateStrategy
        useMappedKeys = options.useMappedKeys
        prettyPrinted = options.prettyPrinted
    }

    /// 编码为二进制 JSON；`prettyPrinted` 开启时带缩进
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        let object = try encodeObject(value)
        var writing: JSONSerialization.WritingOptions = [.fragmentsAllowed]
        if prettyPrinted { writing.insert(.prettyPrinted) }
        return try JSONSerialization.data(withJSONObject: object, options: writing)
    }

    /// 编码为原生字典/数组对象
    public func encodeObject<T: Encodable>(_ value: T) throws -> Any {
        try encodeNode(value).toFoundation()
    }

    /// 编码为内部 JSONNode 树表示；调用方按需再转 Foundation 对象或 Data
    func encodeNode<T: Encodable>(_ value: T) throws -> JSONNode {
        let box = JSONNodeBox()
        let impl = FlexibleEncoderImpl(
            box: box,
            userInfo: userInfo,
            keyStrategy: keyStrategy,
            keyMaps: TypeMappingCache.keyMaps(for: T.self),
            valueMaps: TypeMappingCache.valueMaps(for: T.self),
            dateStrategy: dateStrategy,
            useMappedKeys: useMappedKeys,
            includeIgnoredValues: includeIgnoredValues
        )
        try value.encode(to: impl)
        return box.node
    }
}
