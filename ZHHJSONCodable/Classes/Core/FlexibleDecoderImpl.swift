//
//  FlexibleDecoderImpl.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  自定义 Decoder：缺字段回落 init() 初始值，类型不对尽量转换。
//

import CoreGraphics
import Foundation

/// 自定义 Decoder 实现：缺字段回落 `init()` 初始值，类型不对尽量转换
///
/// 按节点类型分派到 keyed/unkeyed/单值容器，并在模型解码完成后回调 `didFinishMapping`
final class FlexibleDecoderImpl: Decoder {
    var codingPath: [CodingKey]
    /// 透传给自定义 `init(from:)` 的上下文信息
    var userInfo: [CodingUserInfoKey: Any]
    /// 当前要解码的 JSON 节点
    let node: JSONNode
    let keyStrategy: ZHHJSONKeyStrategy
    let dateStrategy: ZHHJSONDateStrategy
    let emptyStringAsNil: Bool
    var keyMaps: [String: [String]]
    var valueMaps: [String: any ZHHJSONTransforming]
    /// 当前类型的 `init()` 模板，用于回读缺失字段的初始值
    var defaultTemplate: Any?
    let decodeIgnoredValues: Bool
    let logSession: ZHHJSONLogSession?

    /// 构造解码器；未传入的映射/模板会在解码时懒加载补全
    init(
        node: JSONNode,
        codingPath: [CodingKey] = [],
        userInfo: [CodingUserInfoKey: Any] = [:],
        keyStrategy: ZHHJSONKeyStrategy = .useDefaultKeys,
        dateStrategy: ZHHJSONDateStrategy = .secondsSince1970,
        emptyStringAsNil: Bool = true,
        keyMaps: [String: [String]] = [:],
        valueMaps: [String: any ZHHJSONTransforming] = [:],
        defaultTemplate: Any? = nil,
        decodeIgnoredValues: Bool = false,
        logSession: ZHHJSONLogSession? = nil
    ) {
        self.node = node
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.keyStrategy = keyStrategy
        self.dateStrategy = dateStrategy
        self.emptyStringAsNil = emptyStringAsNil
        self.keyMaps = keyMaps
        self.valueMaps = valueMaps
        self.defaultTemplate = defaultTemplate
        self.decodeIgnoredValues = decodeIgnoredValues
        self.logSession = logSession
    }

    /// 对象节点转 keyed 容器；非对象时用空字典，让字段逐项回落默认值
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        let object = node.resolvedObject() ?? [:]
        return KeyedDecodingContainer(FlexibleKeyedContainer<Key>(decoder: self, object: object))
    }

    /// 数组节点转 unkeyed 容器；非数组时用空数组
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        FlexibleUnkeyedContainer(decoder: self, array: node.resolvedArray() ?? [])
    }

    /// 标量节点转单值容器
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        FlexibleSingleValueContainer(decoder: self, node: node)
    }

    /// 顶层解码分派：数组/字典/枚举/标量优先，否则走 Codable 递归
    func decodeValue<T: Decodable>(_ type: T.Type) throws -> T {
        if let array = decodeCompactArray(type) { return array }
        if let dictionary = decodeCompactDictionary(type) { return dictionary }
        if let enumType = type as? any ZHHJSONEnum.Type {
            return decodeFlexibleEnum(enumType, from: node) as! T
        }
        if let converted = convertPrimitive(type, node: node) { return converted }
        prepareTemplate(for: type)
        var value = try T(from: self)
        applyFinishMapping(&value)
        return value
    }

    /// 为嵌套字段构造子解码器：继承配置，但换成该字段类型的 key/value 映射与模板
    func child(node: JSONNode, key: CodingKey, type: Any.Type) -> FlexibleDecoderImpl {
        FlexibleDecoderImpl(
            node: node,
            codingPath: codingPath + [key],
            userInfo: userInfo,
            keyStrategy: keyStrategy,
            dateStrategy: dateStrategy,
            emptyStringAsNil: emptyStringAsNil,
            keyMaps: TypeMappingCache.keyMaps(for: type),
            valueMaps: TypeMappingCache.valueMaps(for: type),
            defaultTemplate: template(for: type),
            decodeIgnoredValues: decodeIgnoredValues,
            logSession: logSession
        )
    }

    /// 取类型的 `init()` 实例作为模板
    func template(for type: Any.Type) -> Any? {
        (type as? any ZHHJSONCodable.Type)?.init()
    }

    /// 解码完成后触发模型的二次处理，并把结果写回
    func applyFinishMapping<T>(_ value: inout T) {
        guard var model = value as? any ZHHJSONCodable else { return }
        model.didFinishMapping()
        if let typed = model as? T { value = typed }
    }

    /// 基础类型直接转换；不在范围内的类型返回 nil，交给 Codable 递归
    func convertPrimitive<T>(_ type: T.Type, node: JSONNode) -> T? {
        if T.self == Date.self { return JSONTypeConverter.date(node, strategy: dateStrategy) as? T }
        if T.self == Data.self {
            return JSONTypeConverter.string(node).flatMap { Data(base64Encoded: $0) } as? T
        }
        if T.self == Decimal.self { return JSONTypeConverter.decimal(node) as? T }
        if T.self == CGFloat.self, let value = JSONTypeConverter.double(node) { return CGFloat(value) as? T }
        if T.self == Bool.self { return JSONTypeConverter.bool(node) as? T }
        if T.self == String.self { return JSONTypeConverter.string(node) as? T }
        if T.self == Double.self { return JSONTypeConverter.double(node) as? T }
        if T.self == Float.self { return JSONTypeConverter.float(node) as? T }
        if T.self == Int.self { return JSONTypeConverter.int(node) as? T }
        if T.self == Int8.self { return JSONTypeConverter.int8(node) as? T }
        if T.self == Int16.self { return JSONTypeConverter.int16(node) as? T }
        if T.self == Int32.self { return JSONTypeConverter.int32(node) as? T }
        if T.self == Int64.self { return JSONTypeConverter.int64(node) as? T }
        if T.self == UInt.self { return JSONTypeConverter.uint(node) as? T }
        if T.self == UInt8.self { return JSONTypeConverter.uint8(node) as? T }
        if T.self == UInt16.self { return JSONTypeConverter.uint16(node) as? T }
        if T.self == UInt32.self { return JSONTypeConverter.uint32(node) as? T }
        if T.self == UInt64.self { return JSONTypeConverter.uint64(node) as? T }
        if T.self == URL.self, let text = JSONTypeConverter.string(node), let url = URL(string: text) { return url as? T }
        return nil
    }

    /// 求某字段缺值时的默认值：优先模板里的初始值，其次模型 init / 枚举 fallback / 零值
    func defaultValue<T>(_ type: T.Type, property: String) -> T? {
        if let template = defaultTemplate {
            let result = DefaultValueCache.lookup(type, property: property, template: template)
            if result.found { return result.value }
        }
        if let modelType = type as? any ZHHJSONCodable.Type { return modelType.init() as? T }
        if let enumType = type as? any ZHHJSONEnum.Type { return decodeFlexibleEnum(enumType, from: .null) as? T }
        return JSONDefaultValue.primitive(type)
    }

    /// 懒加载补全模板与映射，避免顶层类型重复计算
    private func prepareTemplate(for type: Any.Type) {
        if defaultTemplate == nil { defaultTemplate = template(for: type) }
        if keyMaps.isEmpty { keyMaps = TypeMappingCache.keyMaps(for: type) }
        if valueMaps.isEmpty { valueMaps = TypeMappingCache.valueMaps(for: type) }
    }

    /// 判断当前节点能否解出目标类型；用于数组/字典跳过脏元素
    func canDecode<T: Decodable>(_ type: T.Type, from node: JSONNode) -> Bool {
        if type is any ZHHJSONCodable.Type { return node.resolvedObject() != nil }
        if type is any FlexibleArrayDecoding.Type { return node.resolvedArray() != nil }
        if type is any FlexibleDictionaryDecoding.Type { return node.resolvedObject() != nil }
        if convertPrimitive(type, node: node) != nil { return true }
        if type is any ZHHJSONEnum.Type {
            return JSONTypeConverter.string(node) != nil || JSONTypeConverter.int64(node) != nil
        }
        if case .object = node { return true }
        if case .array = node { return true }
        return false
    }

    /// 数组类型走 compact 解码：脏元素跳过
    private func decodeCompactArray<T>(_ type: T.Type) -> T? {
        guard let witness = type as? any FlexibleArrayDecoding.Type else { return nil }
        guard let items = node.resolvedArray() else { return nil }
        return witness.decodeFlexibleArray(items: items, parent: self) as? T
    }

    /// 字典类型走 compact 解码：脏 value 跳过对应 key
    private func decodeCompactDictionary<T>(_ type: T.Type) -> T? {
        guard let witness = type as? any FlexibleDictionaryDecoding.Type else { return nil }
        guard let object = node.resolvedObject() else { return nil }
        return witness.decodeFlexibleDictionary(object: object, parent: self) as? T
    }
}

/// 数组 compact 解码协议
protocol FlexibleArrayDecoding {
    static func decodeFlexibleArray(items: [JSONNode], parent: FlexibleDecoderImpl) -> Any
}

/// 字典 compact 解码协议
protocol FlexibleDictionaryDecoding {
    static func decodeFlexibleDictionary(object: [String: JSONNode], parent: FlexibleDecoderImpl) -> Any
}

extension Array: FlexibleArrayDecoding where Element: Decodable {
    /// 数组 compact 解码：无法解码的元素跳过，不让整数组失败
    static func decodeFlexibleArray(items: [JSONNode], parent: FlexibleDecoderImpl) -> Any {
        // compactMap：无法解码的元素返回 nil 被跳过，不让整数组失败
        items.compactMap { item -> Element? in
            guard parent.canDecode(Element.self, from: item) else {
                parent.logSession?.record(
                    path: parent.codingPath,
                    expected: "\(Element.self)",
                    actual: item.typeName,
                    action: "已跳过脏元素"
                )
                return nil
            }
            let child = parent.child(node: item, key: AnyCodingKey(stringValue: "[]"), type: Element.self)
            return try? child.decodeValue(Element.self)
        }
    }
}

extension Dictionary: FlexibleDictionaryDecoding where Key == String, Value: Decodable {
    /// 字典 compact 解码：无法解码的 value 跳过对应 key
    static func decodeFlexibleDictionary(object: [String: JSONNode], parent: FlexibleDecoderImpl) -> Any {
        var result: [String: Value] = [:]
        for (key, node) in object {
            // 无法解码的 value 直接跳过对应 key，不污染结果
            guard parent.canDecode(Value.self, from: node) else {
                parent.logSession?.record(
                    path: parent.codingPath + [AnyCodingKey(stringValue: key)],
                    expected: "\(Value.self)",
                    actual: node.typeName,
                    action: "已跳过脏元素"
                )
                continue
            }
            let child = parent.child(node: node, key: AnyCodingKey(stringValue: key), type: Value.self)
            if let value = try? child.decodeValue(Value.self) {
                result[key] = value
            }
        }
        return result
    }
}
