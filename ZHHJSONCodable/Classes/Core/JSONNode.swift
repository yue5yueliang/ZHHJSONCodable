//
//  JSONNode.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  JSON 中间树，供柔性 Decoder 读取。
//

import Foundation

/// JSON 中间树：统一承载解析后的值，供柔性解码器按节点读取
///
/// 用枚举区分对象/数组/字符串/数字/布尔/空，避免解码过程反复与 Foundation 对象类型博弈
enum JSONNode {
    case object([String: JSONNode])
    case array([JSONNode])
    case string(String)
    case number(NSNumber)
    case bool(Bool)
    case null
}

extension JSONNode {

    /// 把任意 Foundation/JSONNode 值递归转成 JSONNode；无法识别的类型落为 `.null`
    static func from(_ value: Any) -> JSONNode {
        switch value {
        case is NSNull:
            return .null
        case let node as JSONNode:
            return node
        case let number as NSNumber:
            // JSON 里的 true/false 也是 NSNumber，必须先于普通数字判断
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            return .number(number)
        case let bool as Bool:
            return .bool(bool)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(array.map(from))
        case let object as [String: Any]:
            return .object(object.mapValues(from))
        default:
            return .null
        }
    }

    /// 解析二进制 JSON；支持顶层是标量/数组等片段
    static func parse(data: Data) throws -> JSONNode {
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return from(object)
    }

    /// 解析 JSON 字符串；转 UTF-8 Data 失败时抛 `dataCorrupted`
    static func parse(json: String) throws -> JSONNode {
        guard let data = json.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "JSON 字符串无法转成 Data"))
        }
        return try parse(data: data)
    }

    /// 按 `a.b.0.c` 下钻；数字段走数组下标
    func node(at path: String?) -> JSONNode? {
        guard let path, !path.isEmpty else { return self }
        var current = self
        for segment in path.split(separator: ".").map(String.init) {
            if case .object(let object) = current, let next = object[segment] {
                current = next
                continue
            }
            if case .array(let array) = current, let index = Int(segment), array.indices.contains(index) {
                current = array[index]
                continue
            }
            return nil
        }
        return current
    }

    /// 期望对象时，若实际是 JSON 字符串则再解析一层
    func resolvedObject() -> [String: JSONNode]? {
        switch self {
        case .object(let object):
            return object
        case .string(let text):
            guard let parsed = try? JSONNode.parse(json: text), case .object(let object) = parsed else { return nil }
            return object
        default:
            return nil
        }
    }

    /// 期望数组时，若实际是 JSON 字符串则再解析一层
    func resolvedArray() -> [JSONNode]? {
        switch self {
        case .array(let array):
            return array
        case .string(let text):
            guard let parsed = try? JSONNode.parse(json: text), case .array(let array) = parsed else { return nil }
            return array
        default:
            return nil
        }
    }

    /// 递归转回 Foundation 对象，供编码/输出使用
    func toFoundation() -> Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .number(let number):
            return number
        case .string(let value):
            return value
        case .array(let array):
            return array.map { $0.toFoundation() }
        case .object(let object):
            return object.mapValues { $0.toFoundation() }
        }
    }

    var typeName: String {
        switch self {
        case .null: return "null"
        case .bool: return "Bool"
        case .number: return "Number"
        case .string: return "String"
        case .array: return "Array"
        case .object: return "Object"
        }
    }
}
