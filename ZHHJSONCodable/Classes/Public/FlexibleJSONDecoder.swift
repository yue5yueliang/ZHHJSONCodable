//
//  FlexibleJSONDecoder.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  对外 Decoder：Data / String / 字典 / 数组均可。
//

import Foundation

/// 柔性解码器：接受 Data / String / 字典 / 数组，内部统一转成 JSONNode 后再解码
///
/// 相比原生 `JSONDecoder`，主差异在于：缺字段回落 `init()`、类型尽量转换、数组跳过脏元素
public final class FlexibleJSONDecoder {
    /// JSON key 命名策略（默认原样使用）
    public var keyStrategy: ZHHJSONKeyStrategy = .useDefaultKeys
    /// 日期解析策略（默认按秒级时间戳）
    public var dateStrategy: ZHHJSONDateStrategy = .secondsSince1970
    /// 空字符串是否当 nil 处理（默认 true）
    public var emptyStringAsNil = true
    /// 日志上下文，仅用于定位报错来源，不参与解码
    public var logContext: String?
    /// 透传给自定义 `init(from:)` 的上下文信息
    public var userInfo: [CodingUserInfoKey: Any] = [:]
    /// 内部开关：是否解码被 `@ZHHJSONIgnored` 标记的字段（默认不）
    var decodeIgnoredValues = false

    public init() {}

    /// 用解码配置初始化
    public convenience init(options: ZHHJSONDecodeOptions) {
        self.init()
        keyStrategy = options.keyStrategy
        dateStrategy = options.dateStrategy
        emptyStringAsNil = options.emptyStringAsNil
        logContext = options.logContext
    }

    /// 从二进制数据解码
    public func decode<T: Decodable>(_ type: T.Type, from data: Data, path: String? = nil) throws -> T {
        try decode(type, from: parseNode(data: data), path: path)
    }

    /// 从 JSON 字符串解码
    public func decode<T: Decodable>(_ type: T.Type, from json: String, path: String? = nil) throws -> T {
        try decode(type, from: parseNode(json: json), path: path)
    }

    /// 从原生字典/数组对象解码
    public func decode<T: Decodable>(_ type: T.Type, from object: Any, path: String? = nil) throws -> T {
        try decode(type, from: JSONNode.from(object), path: path)
    }

    /// 统一解码入口：先按 path 定位节点，再交给内部实现，失败时统一包装成 `ZHHJSONDecodeError`
    func decode<T: Decodable>(_ type: T.Type, from node: JSONNode, path: String? = nil) throws -> T {
        // path 取不到节点直接抛路径错误，不进入后续解码
        guard let target = node.node(at: path) else {
            throw ZHHJSONDecodeError.pathNotFound(path ?? "")
        }
        let session = ZHHJSONLogSession(typeName: "\(type)", context: logContext)
        let impl = FlexibleDecoderImpl(
            node: target,
            userInfo: userInfo,
            keyStrategy: keyStrategy,
            dateStrategy: dateStrategy,
            emptyStringAsNil: emptyStringAsNil,
            keyMaps: TypeMappingCache.keyMaps(for: type),
            valueMaps: TypeMappingCache.valueMaps(for: type),
            defaultTemplate: (type as? any ZHHJSONCodable.Type)?.init(),
            decodeIgnoredValues: decodeIgnoredValues,
            logSession: session
        )
        do {
            let value = try impl.decodeValue(type)
            session.flush()
            return value
        } catch let error as ZHHJSONDecodeError {
            // 已是本库错误则原样抛出，避免重复包装
            session.flush()
            throw error
        } catch {
            // 其他异常兜底为 failed，保留底层错误
            session.flush()
            throw ZHHJSONDecodeError.failed(underlying: error)
        }
    }

    /// 解析二进制为 JSONNode；解析失败映射为 `invalidJSON`
    private func parseNode(data: Data) throws -> JSONNode {
        do {
            return try JSONNode.parse(data: data)
        } catch {
            throw ZHHJSONDecodeError.invalidJSON(underlying: error)
        }
    }

    /// 解析字符串为 JSONNode；解析失败映射为 `invalidJSON`
    private func parseNode(json: String) throws -> JSONNode {
        do {
            return try JSONNode.parse(json: json)
        } catch {
            throw ZHHJSONDecodeError.invalidJSON(underlying: error)
        }
    }

}
