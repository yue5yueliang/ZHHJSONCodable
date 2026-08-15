//
//  ZHHJSONUpdater.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  用新 JSON 只覆盖出现过的字段，嵌套对象递归合并，保留未下发的旧值。
//

import Foundation

/// 局部更新错误类型
public enum ZHHJSONUpdateError: Error {
    /// 输入为 nil 或空
    case emptyInput
    /// JSON 非法
    case invalidJSON(underlying: Error)
    /// path 在 JSON 里不存在
    case pathNotFound(String)
    /// 更新内容不是对象（无法做字段合并）
    case notObject
    /// 编码当前模型失败
    case encodeFailed(underlying: Error)
    /// 合并后解码回模型失败
    case decodeFailed(ZHHJSONDecodeError)
}

extension ZHHJSONUpdateError: LocalizedError {
    /// 各类更新错误的用户可读文案
    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "输入为空"
        case .invalidJSON(let error):
            return "JSON 无效: \(error.localizedDescription)"
        case .pathNotFound(let path):
            return "路径不存在: \(path)"
        case .notObject:
            return "更新内容不是对象"
        case .encodeFailed(let error):
            return "编码当前模型失败: \(error.localizedDescription)"
        case .decodeFailed(let error):
            return error.errorDescription ?? "解码失败"
        }
    }
}

/// 局部更新工具：用新 JSON 只覆盖出现过的字段，未下发的旧值保留
public enum ZHHJSONUpdater {

    /// 从二进制数据做局部更新；入参为空抛 `emptyInput`
    public static func update<T: ZHHJSONCodable>(
        _ model: inout T,
        from data: Data?,
        path: String? = nil,
        decodeOptions: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions(),
        encodeOptions: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()
    ) throws {
        guard let data, !data.isEmpty else { throw ZHHJSONUpdateError.emptyInput }
        let node: JSONNode
        do {
            node = try JSONNode.parse(data: data)
        } catch {
            throw ZHHJSONUpdateError.invalidJSON(underlying: error)
        }
        try update(&model, from: node, path: path, decodeOptions: decodeOptions, encodeOptions: encodeOptions)
    }

    /// 从 JSON 字符串做局部更新；入参为空抛 `emptyInput`
    public static func update<T: ZHHJSONCodable>(
        _ model: inout T,
        from json: String?,
        path: String? = nil,
        decodeOptions: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions(),
        encodeOptions: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()
    ) throws {
        guard let json, !json.isEmpty else { throw ZHHJSONUpdateError.emptyInput }
        let node: JSONNode
        do {
            node = try JSONNode.parse(json: json)
        } catch {
            throw ZHHJSONUpdateError.invalidJSON(underlying: error)
        }
        try update(&model, from: node, path: path, decodeOptions: decodeOptions, encodeOptions: encodeOptions)
    }

    /// 从原生对象做局部更新；入参为 nil 抛 `emptyInput`
    public static func update<T: ZHHJSONCodable>(
        _ model: inout T,
        from object: Any?,
        path: String? = nil,
        decodeOptions: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions(),
        encodeOptions: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()
    ) throws {
        guard let object else { throw ZHHJSONUpdateError.emptyInput }
        try update(&model, from: JSONNode.from(object), path: path, decodeOptions: decodeOptions, encodeOptions: encodeOptions)
    }

    /// 局部更新失败时返回 false，不抛错
    @discardableResult
    public static func updateIfPresent<T: ZHHJSONCodable>(
        _ model: inout T,
        from data: Data?,
        path: String? = nil,
        decodeOptions: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions(),
        encodeOptions: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()
    ) -> Bool {
        do {
            try update(&model, from: data, path: path, decodeOptions: decodeOptions, encodeOptions: encodeOptions)
            return true
        } catch {
            return false
        }
    }

    /// 局部更新失败时返回 false，不抛错
    @discardableResult
    public static func updateIfPresent<T: ZHHJSONCodable>(
        _ model: inout T,
        from json: String?,
        path: String? = nil,
        decodeOptions: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions(),
        encodeOptions: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()
    ) -> Bool {
        do {
            try update(&model, from: json, path: path, decodeOptions: decodeOptions, encodeOptions: encodeOptions)
            return true
        } catch {
            return false
        }
    }

    /// 局部更新失败时返回 false，不抛错
    @discardableResult
    public static func updateIfPresent<T: ZHHJSONCodable>(
        _ model: inout T,
        from object: Any?,
        path: String? = nil,
        decodeOptions: ZHHJSONDecodeOptions = ZHHJSONDecodeOptions(),
        encodeOptions: ZHHJSONEncodeOptions = ZHHJSONEncodeOptions()
    ) -> Bool {
        do {
            try update(&model, from: object, path: path, decodeOptions: decodeOptions, encodeOptions: encodeOptions)
            return true
        } catch {
            return false
        }
    }

    /// 核心合并流程：把当前模型编码成字典，用新 JSON 覆盖出现过的键，再解码回模型
    private static func update<T: ZHHJSONCodable>(
        _ model: inout T,
        from node: JSONNode,
        path: String?,
        decodeOptions: ZHHJSONDecodeOptions,
        encodeOptions: ZHHJSONEncodeOptions
    ) throws {
        // path 取不到节点则报路径错误
        guard let incoming = node.node(at: path) else {
            throw ZHHJSONUpdateError.pathNotFound(path ?? "")
        }
        // 局部更新要求目标必须是对象，数组/标量无法合并
        guard case .object(let patch) = incoming else {
            throw ZHHJSONUpdateError.notObject
        }
        // 编码时开启 key 映射与被忽略字段，保证合并键和补丁键对齐
        let encoder = FlexibleJSONEncoder(options: encodeOptions)
        encoder.useMappedKeys = true
        encoder.includeIgnoredValues = true
        let current: JSONNode
        do {
            current = try encoder.encodeNode(model)
        } catch {
            throw ZHHJSONUpdateError.encodeFailed(underlying: error)
        }
        guard case .object(var merged) = current else {
            throw ZHHJSONUpdateError.encodeFailed(underlying: EncodingError.invalidValue(model, .init(codingPath: [], debugDescription: "当前模型不是对象")))
        }
        // 把补丁归一化后递归合并进当前对象，再整体解码回模型
        merge(&merged, from: normalizedPatch(patch, for: T.self))
        do {
            let decoder = FlexibleJSONDecoder(options: decodeOptions)
            decoder.decodeIgnoredValues = true
            model = try decoder.decode(T.self, from: JSONNode.object(merged).toFoundation())
        } catch let error as ZHHJSONDecodeError {
            throw ZHHJSONUpdateError.decodeFailed(error)
        } catch {
            throw ZHHJSONUpdateError.decodeFailed(.failed(underlying: error))
        }
    }

    /// 递归合并：两边都是对象则逐层下钻，否则直接用新值覆盖
    private static func merge(_ dest: inout [String: JSONNode], from src: [String: JSONNode]) {
        for (key, value) in src {
            if case .object(let srcObject) = value, case .object(var destObject) = dest[key] {
                merge(&destObject, from: srcObject)
                dest[key] = .object(destObject)
            } else {
                dest[key] = value
            }
        }
    }

    /// 把补丁 key 归一化到规范名，并对嵌套对象递归归一化
    private static func normalizedPatch(_ patch: [String: JSONNode], for type: any ZHHJSONCodable.Type) -> [String: JSONNode] {
        let maps = TypeMappingCache.keyMaps(for: type)
        var aliases: [String: String] = [:]
        // 首个 key 作为规范名，其余都作为别名指向它
        for (property, keys) in maps where !keys.isEmpty {
            let canonical = keys[0]
            aliases[property] = canonical
            for key in keys { aliases[key] = canonical }
        }
        let nested = nestedCodableTypes(of: type, maps: maps, aliases: aliases)
        var result: [String: JSONNode] = [:]
        for (key, value) in patch {
            let canonical = aliases[key] ?? key
            if case .object(let object) = value, let nestedType = nested[canonical] ?? nested[key] {
                result[canonical] = .object(normalizedPatch(object, for: nestedType))
            } else {
                result[canonical] = value
            }
        }
        return result
    }

    /// 用反射收集所有嵌套 `ZHHJSONCodable` 属性及其 key 别名，供递归归一化使用
    private static func nestedCodableTypes(
        of type: any ZHHJSONCodable.Type,
        maps: [String: [String]],
        aliases: [String: String]
    ) -> [String: any ZHHJSONCodable.Type] {
        var result: [String: any ZHHJSONCodable.Type] = [:]
        var mirror: Mirror? = Mirror(reflecting: type.init())
        // 沿继承链向上遍历，把每个嵌套模型类型记录到所有候选 key 名下
        while let current = mirror {
            for child in current.children {
                guard let label = child.label else { continue }
                let name = label.hasPrefix("_") ? String(label.dropFirst()) : label
                guard let nested = NestedJSONType.jsonCodable(of: child.value) else { continue }
                var keys = Set([name, label] + (maps[name] ?? []))
                keys.formUnion(keys.compactMap { aliases[$0] })
                for key in keys {
                    result[key] = nested
                }
            }
            mirror = current.superclassMirror
        }
        return result
    }
}

/// 让 Optional 暴露其包裹类型，供反射时剥掉可选层
private protocol OptionalTypeWitness {
    static var wrappedType: Any.Type { get }
}

extension Optional: OptionalTypeWitness {
    static var wrappedType: Any.Type { Wrapped.self }
}

/// 判断/提取值中嵌套的 `ZHHJSONCodable` 类型，支持 Optional 与属性包装器
private enum NestedJSONType {
    static func jsonCodable(of value: Any) -> (any ZHHJSONCodable.Type)? {
        // 先剥掉可选层直接判断类型
        if let nested = unwrap(type(of: value)) as? any ZHHJSONCodable.Type {
            return nested
        }
        // 再通过 wrappedValue 下钻属性包装器
        let mirror = Mirror(reflecting: value)
        if let wrapped = mirror.children.first(where: { $0.label == "wrappedValue" }) {
            return jsonCodable(of: wrapped.value)
        }
        return nil
    }

    /// 递归剥掉 Optional 层，返回最内层的具体类型
    static func unwrap(_ type: Any.Type) -> Any.Type {
        var current = type
        while let optional = current as? OptionalTypeWitness.Type {
            current = optional.wrappedType
        }
        return current
    }
}
