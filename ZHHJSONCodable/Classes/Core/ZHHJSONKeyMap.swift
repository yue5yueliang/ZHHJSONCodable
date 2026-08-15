//
//  ZHHJSONKeyMap.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import Foundation

/// 一个属性对应多个候选 JSON key，按顺序取第一个有值的
public struct ZHHJSONKeyMap {
    public let propertyName: String
    public let jsonKeys: [String]

    /// 用属性 CodingKey 与可变个候选 key 构造映射项
    public init(_ key: some CodingKey, _ jsonKeys: String...) {
        self.propertyName = key.stringValue
        self.jsonKeys = jsonKeys
    }

    /// 用属性 CodingKey 与候选 key 数组构造映射项
    public init(_ key: some CodingKey, jsonKeys: [String]) {
        self.propertyName = key.stringValue
        self.jsonKeys = jsonKeys
    }
}

/// key 命名策略：原样使用，或把驼峰转下划线
public enum ZHHJSONKeyStrategy {
    case useDefaultKeys
    case convertFromSnakeCase
}

/// 按属性名解析实际 JSON key 与节点
enum JSONKeyResolver {

    /// 命中候选 key 时返回属性名本身；当前未调用方使用，保留供后续扩展
    static func jsonKey(
        for property: String,
        object: [String: JSONNode],
        maps: [String: [String]],
        strategy: ZHHJSONKeyStrategy
    ) -> String? {
        if resolvedNode(for: property, object: object, maps: maps, strategy: strategy) != nil {
            return property
        }
        return nil
    }

    /// 按候选 key 顺序取第一个非 null 节点；都命中但为 null 时退而取第一个存在的节点
    static func resolvedNode(
        for property: String,
        object: [String: JSONNode],
        maps: [String: [String]],
        strategy: ZHHJSONKeyStrategy
    ) -> JSONNode? {
        if let candidates = maps[property] {
            // 第一轮：优先非 null 值
            for key in candidates {
                if let node = node(for: key, in: object), !isNull(node) { return node }
            }
            // 第二轮：候选全是 null 时，返回第一个存在的 null（与缺字段区分）
            for key in candidates {
                if let node = node(for: key, in: object) { return node }
            }
        }
        // 无映射时按属性名原样取，再尝试下划线命名
        if let node = object[property] { return node }
        if strategy == .convertFromSnakeCase, let node = object[toSnakeCase(property)] { return node }
        return nil
    }

    /// 取 key 对应节点；含 `.` 时按路径下钻，否则直接取字段
    static func node(for key: String, in object: [String: JSONNode]) -> JSONNode? {
        if key.contains(".") { return JSONNode.object(object).node(at: key) }
        return object[key]
    }

    /// 驼峰转下划线：每个大写字母前都插分隔符，无视上下文
    static func toSnakeCase(_ text: String) -> String {
        var result = ""
        for character in text {
            if character.isUppercase {
                if !result.isEmpty { result.append("_") }
                result.append(character.lowercased())
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// 判断节点是否为 null（nil 视为非 null，交由调用方区分）
    private static func isNull(_ node: JSONNode?) -> Bool {
        if case .null = node { return true }
        return false
    }
}
