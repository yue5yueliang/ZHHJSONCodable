//
//  ZHHJSONOptions.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  用结构体传策略，不用 Set<enum>（关联值会被 Hashable 吃掉）。
//

import Foundation

/// 解码配置：集中承载策略，避免方法参数过长
public struct ZHHJSONDecodeOptions {
    /// key 命名策略
    public var keyStrategy: ZHHJSONKeyStrategy
    /// 日期解析策略
    public var dateStrategy: ZHHJSONDateStrategy
    /// 空字符串是否当 nil（默认 true）
    public var emptyStringAsNil: Bool
    /// 日志上下文，仅用于定位来源
    public var logContext: String?

    /// 用各项策略构造解码配置，均有默认值
    public init(
        keyStrategy: ZHHJSONKeyStrategy = .useDefaultKeys,
        dateStrategy: ZHHJSONDateStrategy = .secondsSince1970,
        emptyStringAsNil: Bool = true,
        logContext: String? = nil
    ) {
        self.keyStrategy = keyStrategy
        self.dateStrategy = dateStrategy
        self.emptyStringAsNil = emptyStringAsNil
        self.logContext = logContext
    }
}

/// 编码配置：集中承载策略，避免方法参数过长
public struct ZHHJSONEncodeOptions {
    /// key 命名策略
    public var keyStrategy: ZHHJSONKeyStrategy
    /// 日期序列化策略
    public var dateStrategy: ZHHJSONDateStrategy
    /// 是否按 `keyMapping()` 映射属性名（默认开启）
    public var useMappedKeys: Bool
    /// 是否带缩进输出（默认紧凑）
    public var prettyPrinted: Bool

    /// 用各项策略构造编码配置，均有默认值
    public init(
        keyStrategy: ZHHJSONKeyStrategy = .useDefaultKeys,
        dateStrategy: ZHHJSONDateStrategy = .secondsSince1970,
        useMappedKeys: Bool = true,
        prettyPrinted: Bool = false
    ) {
        self.keyStrategy = keyStrategy
        self.dateStrategy = dateStrategy
        self.useMappedKeys = useMappedKeys
        self.prettyPrinted = prettyPrinted
    }
}
