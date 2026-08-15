//
//  ZHHJSONCodable.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  柔性 Codable：缺字段回落 init() 初始值，类型不匹配尽量转换。
//

import Foundation

/// 柔性 Codable 协议：解码时缺字段回落 `init()` 初始值，类型不匹配尽量转换，而非直接抛错
///
/// 实现方只需提供 `init()`，其余方法均有默认空实现，可按需重写
public protocol ZHHJSONCodable: Codable {
    /// 无参构造：缺字段、类型转换失败时，用这个初始值兜底
    init()

    /// 属性 → 多个候选 JSON key，按顺序取第一个有值的；支持 `a.b.0.c`
    static func keyMapping() -> [ZHHJSONKeyMap]

    /// 属性 → 值转换器
    static func valueMapping() -> [ZHHJSONValueMap]

    /// 解码完成后的二次处理
    mutating func didFinishMapping()
}

public extension ZHHJSONCodable {
    /// 默认无 key 映射
    static func keyMapping() -> [ZHHJSONKeyMap] { [] }
    /// 默认无值转换器
    static func valueMapping() -> [ZHHJSONValueMap] { [] }
    /// 默认无二次处理
    mutating func didFinishMapping() {}

    /// 从二进制数据解码；入参为空时抛 `emptyInput`
    static func decode(
        from data: Data?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) throws -> Self {
        guard let data, !data.isEmpty else { throw ZHHJSONDecodeError.emptyInput }
        return try decodeResolved(FlexibleJSONDecoder(options: options).decode(Self.self, from: data, path: path), path: path)
    }

    /// 从 JSON 字符串解码；入参为空时抛 `emptyInput`
    static func decode(
        from json: String?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) throws -> Self {
        guard let json, !json.isEmpty else { throw ZHHJSONDecodeError.emptyInput }
        return try decodeResolved(FlexibleJSONDecoder(options: options).decode(Self.self, from: json, path: path), path: path)
    }

    /// 从字典/数组等原生对象解码；入参为 nil 时抛 `emptyInput`
    static func decode(
        from object: Any?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) throws -> Self {
        guard let object else { throw ZHHJSONDecodeError.emptyInput }
        return try decodeResolved(FlexibleJSONDecoder(options: options).decode(Self.self, from: object, path: path), path: path)
    }

    /// 解码失败返回 nil，而非抛错
    static func decodeIfPresent(
        from data: Data?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) -> Self? {
        try? decode(from: data, path: path, options: options)
    }

    /// 解码失败返回 nil，而非抛错
    static func decodeIfPresent(
        from json: String?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) -> Self? {
        try? decode(from: json, path: path, options: options)
    }

    /// 解码失败返回 nil，而非抛错
    static func decodeIfPresent(
        from object: Any?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) -> Self? {
        try? decode(from: object, path: path, options: options)
    }

    /// 编码为二进制数据
    func encodeData(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) throws -> Data {
        try FlexibleJSONEncoder(options: options).encode(self)
    }

    /// 编码为原生字典/数组对象
    func encodeObject(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) throws -> Any {
        try FlexibleJSONEncoder(options: options).encodeObject(self)
    }

    /// 编码为 JSON 字符串；生成 UTF-8 失败时抛 `EncodingError.invalidValue`
    func encodeJSONString(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) throws -> String {
        let data = try encodeData(options: options)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "无法生成 UTF-8 JSON"))
        }
        return string
    }

    /// 编码失败时返回 nil，而非抛错
    func encodeDataIfPresent(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) -> Data? {
        try? encodeData(options: options)
    }

    /// 编码失败时返回 nil，而非抛错
    func encodeObjectIfPresent(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) -> Any? {
        try? encodeObject(options: options)
    }

    /// 编码失败时返回 nil，而非抛错
    func encodeJSONStringIfPresent(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) -> String? {
        try? encodeJSONString(options: options)
    }

    /// 统一把解码错误映射为带 path 上下文的 `ZHHJSONDecodeError`
    private static func decodeResolved(_ work: @autoclosure () throws -> Self, path: String?) throws -> Self {
        do {
            return try work()
        } catch {
            throw ZHHJSONDecodeErrorMapper.map(error, path: path)
        }
    }
}

/// 数组元素符合 `ZHHJSONCodable` 时的批量解码入口
public extension Array where Element: ZHHJSONCodable {
    /// 从二进制数据解码；入参为空时抛 `emptyInput`
    static func decode(
        from data: Data?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) throws -> [Element] {
        guard let data, !data.isEmpty else { throw ZHHJSONDecodeError.emptyInput }
        return try decodeResolved(FlexibleJSONDecoder(options: options).decode([Element].self, from: data, path: path), path: path)
    }

    /// 从 JSON 字符串解码；入参为空时抛 `emptyInput`
    static func decode(
        from json: String?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) throws -> [Element] {
        guard let json, !json.isEmpty else { throw ZHHJSONDecodeError.emptyInput }
        return try decodeResolved(FlexibleJSONDecoder(options: options).decode([Element].self, from: json, path: path), path: path)
    }

    /// 从原生数组对象解码；入参为 nil 时抛 `emptyInput`
    static func decode(
        from object: Any?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) throws -> [Element] {
        guard let object else { throw ZHHJSONDecodeError.emptyInput }
        return try decodeResolved(FlexibleJSONDecoder(options: options).decode([Element].self, from: object, path: path), path: path)
    }

    /// 解码失败返回 nil，而非抛错
    static func decodeIfPresent(
        from data: Data?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) -> [Element]? {
        try? decode(from: data, path: path, options: options)
    }

    /// 解码失败返回 nil，而非抛错
    static func decodeIfPresent(
        from json: String?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) -> [Element]? {
        try? decode(from: json, path: path, options: options)
    }

    /// 解码失败返回 nil，而非抛错
    static func decodeIfPresent(
        from object: Any?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) -> [Element]? {
        try? decode(from: object, path: path, options: options)
    }

    /// 编码为二进制数据
    func encodeData(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) throws -> Data {
        try FlexibleJSONEncoder(options: options).encode(self)
    }

    /// 编码为原生数组对象
    func encodeObject(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) throws -> Any {
        try FlexibleJSONEncoder(options: options).encodeObject(self)
    }

    /// 编码为 JSON 字符串；生成 UTF-8 失败时抛 `EncodingError.invalidValue`
    func encodeJSONString(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) throws -> String {
        let data = try encodeData(options: options)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "无法生成 UTF-8 JSON"))
        }
        return string
    }

    /// 编码失败返回 nil，而非抛错
    func encodeDataIfPresent(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) -> Data? {
        try? encodeData(options: options)
    }

    /// 编码失败返回 nil，而非抛错
    func encodeObjectIfPresent(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) -> Any? {
        try? encodeObject(options: options)
    }

    /// 编码失败返回 nil，而非抛错
    func encodeJSONStringIfPresent(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) -> String? {
        try? encodeJSONString(options: options)
    }

    /// 统一把解码错误映射为带 path 上下文的 `ZHHJSONDecodeError`
    private static func decodeResolved(_ work: @autoclosure () throws -> [Element], path: String?) throws -> [Element] {
        do {
            return try work()
        } catch {
            throw ZHHJSONDecodeErrorMapper.map(error, path: path)
        }
    }
}

/// 字典 value 符合 `ZHHJSONCodable` 时的批量解码入口
public extension Dictionary where Key == String, Value: ZHHJSONCodable {
    /// 从二进制数据解码；入参为空时抛 `emptyInput`
    static func decode(
        from data: Data?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) throws -> [String: Value] {
        guard let data, !data.isEmpty else { throw ZHHJSONDecodeError.emptyInput }
        return try decodeResolved(FlexibleJSONDecoder(options: options).decode([String: Value].self, from: data, path: path), path: path)
    }

    /// 从 JSON 字符串解码；入参为空时抛 `emptyInput`
    static func decode(
        from json: String?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) throws -> [String: Value] {
        guard let json, !json.isEmpty else { throw ZHHJSONDecodeError.emptyInput }
        return try decodeResolved(FlexibleJSONDecoder(options: options).decode([String: Value].self, from: json, path: path), path: path)
    }

    /// 从原生字典对象解码；入参为 nil 时抛 `emptyInput`
    static func decode(
        from object: Any?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) throws -> [String: Value] {
        guard let object else { throw ZHHJSONDecodeError.emptyInput }
        return try decodeResolved(FlexibleJSONDecoder(options: options).decode([String: Value].self, from: object, path: path), path: path)
    }

    /// 解码失败返回 nil，而非抛错
    static func decodeIfPresent(
        from data: Data?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) -> [String: Value]? {
        try? decode(from: data, path: path, options: options)
    }

    /// 解码失败返回 nil，而非抛错
    static func decodeIfPresent(
        from json: String?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) -> [String: Value]? {
        try? decode(from: json, path: path, options: options)
    }

    /// 解码失败返回 nil，而非抛错
    static func decodeIfPresent(
        from object: Any?,
        path: String? = nil,
        options: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions()
    ) -> [String: Value]? {
        try? decode(from: object, path: path, options: options)
    }

    /// 编码为二进制数据
    func encodeData(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) throws -> Data {
        try FlexibleJSONEncoder(options: options).encode(self)
    }

    /// 编码为原生字典对象
    func encodeObject(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) throws -> Any {
        try FlexibleJSONEncoder(options: options).encodeObject(self)
    }

    /// 编码为 JSON 字符串；生成 UTF-8 失败时抛 `EncodingError.invalidValue`
    func encodeJSONString(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) throws -> String {
        let data = try encodeData(options: options)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "无法生成 UTF-8 JSON"))
        }
        return string
    }

    /// 编码失败返回 nil，而非抛错
    func encodeDataIfPresent(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) -> Data? {
        try? encodeData(options: options)
    }

    /// 编码失败返回 nil，而非抛错
    func encodeObjectIfPresent(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) -> Any? {
        try? encodeObject(options: options)
    }

    /// 编码失败返回 nil，而非抛错
    func encodeJSONStringIfPresent(options: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()) -> String? {
        try? encodeJSONString(options: options)
    }

    /// 统一把解码错误映射为带 path 上下文的 `ZHHJSONDecodeError`
    private static func decodeResolved(_ work: @autoclosure () throws -> [String: Value], path: String?) throws -> [String: Value] {
        do {
            return try work()
        } catch {
            throw ZHHJSONDecodeErrorMapper.map(error, path: path)
        }
    }
}
