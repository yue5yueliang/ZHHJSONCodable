//
//  FlexibleEncoderImpl.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import Foundation

/// 可变的 JSONNode 容器：值变化时回调，供嵌套容器把结果写回父节点
final class JSONNodeBox {
    var node: JSONNode {
        didSet { onChange?(node) }
    }

    private let onChange: ((JSONNode) -> Void)?

    /// 构造节点容器；可选传入值变化回调（供嵌套容器回填父节点）
    init(node: JSONNode = .null, onChange: ((JSONNode) -> Void)? = nil) {
        self.node = node
        self.onChange = onChange
    }
}

/// 自定义 Encoder 实现：编码过程写入 JSONNodeBox，支持 key 映射与值转换
final class FlexibleEncoderImpl: Encoder {
    var codingPath: [CodingKey]
    /// 透传给自定义 `encode(to:)` 的上下文信息
    var userInfo: [CodingUserInfoKey: Any]
    let box: JSONNodeBox
    let keyStrategy: ZHHJSONKeyStrategy
    let keyMaps: [String: [String]]
    let valueMaps: [String: any ZHHJSONTransforming]
    let dateStrategy: ZHHJSONDateStrategy
    /// 是否把属性名按 keyMapping 映射（默认开启）
    let useMappedKeys: Bool
    /// 是否输出被忽略字段（默认关闭）
    let includeIgnoredValues: Bool

    /// 构造编码器；各项策略与映射均可选
    init(
        box: JSONNodeBox = JSONNodeBox(),
        codingPath: [CodingKey] = [],
        userInfo: [CodingUserInfoKey: Any] = [:],
        keyStrategy: ZHHJSONKeyStrategy = .useDefaultKeys,
        keyMaps: [String: [String]] = [:],
        valueMaps: [String: any ZHHJSONTransforming] = [:],
        dateStrategy: ZHHJSONDateStrategy = .secondsSince1970,
        useMappedKeys: Bool = true,
        includeIgnoredValues: Bool = false
    ) {
        self.box = box
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.keyStrategy = keyStrategy
        self.keyMaps = keyMaps
        self.valueMaps = valueMaps
        self.dateStrategy = dateStrategy
        self.useMappedKeys = useMappedKeys
        self.includeIgnoredValues = includeIgnoredValues
    }

    /// 对象编码容器；非对象时先初始化空对象
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        if case .object = box.node {} else { box.node = .object([:]) }
        return KeyedEncodingContainer(FlexibleKeyedEncoder<Key>(encoder: self))
    }

    /// 数组编码容器；非数组时先初始化空数组
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        if case .array = box.node {} else { box.node = .array([]) }
        return FlexibleUnkeyedEncoder(encoder: self)
    }

    /// 单值编码容器
    func singleValueContainer() -> SingleValueEncodingContainer {
        FlexibleSingleValueEncoder(encoder: self)
    }

    /// 求属性最终输出的 key：优先映射首 key，其次蛇形命名，最后原样
    func encodedKey(for property: String) -> String {
        if useMappedKeys, let first = keyMaps[property]?.first { return first }
        if keyStrategy == .convertFromSnakeCase { return JSONKeyResolver.toSnakeCase(property) }
        return property
    }

    /// 为嵌套字段构造子编码器，换成该类型的映射
    func childEncoder(box: JSONNodeBox, key: CodingKey?, type: Any.Type) -> FlexibleEncoderImpl {
        FlexibleEncoderImpl(
            box: box,
            codingPath: key.map { codingPath + [$0] } ?? codingPath,
            userInfo: userInfo,
            keyStrategy: keyStrategy,
            keyMaps: TypeMappingCache.keyMaps(for: type),
            valueMaps: TypeMappingCache.valueMaps(for: type),
            dateStrategy: dateStrategy,
            useMappedKeys: useMappedKeys,
            includeIgnoredValues: includeIgnoredValues
        )
    }

    /// 把节点写回数组指定下标（供嵌套容器回填）
    func replace(_ node: JSONNode, at index: Int) {
        guard case .array(var array) = box.node, array.indices.contains(index) else { return }
        array[index] = node
        box.node = .array(array)
    }

    /// 日期转节点；转换失败时回落 0
    func dateNode(_ date: Date) -> JSONNode {
        JSONNode.from(ZHHJSONDateTransform(dateFormat).toJSON(date) ?? 0)
    }

    /// 双精度数字转节点；nan/inf 抛 `EncodingError`，避免产出非法 JSON
    func numberNode(_ value: Double) throws -> JSONNode {
        guard value.isFinite else {
            throw EncodingError.invalidValue(value, .init(codingPath: codingPath, debugDescription: "JSON 不支持非有限数字"))
        }
        return .number(NSNumber(value: value))
    }

    /// 单精度数字转节点；复用 Double 路径做非有限值校验
    func numberNode(_ value: Float) throws -> JSONNode {
        try numberNode(Double(value))
    }

    /// 日期策略转成对应格式化格式；automatic 编码时按秒级时间戳
    private var dateFormat: ZHHJSONDateTransform.Format {
        switch dateStrategy {
        case .secondsSince1970: return .secondsSince1970
        case .millisecondsSince1970: return .millisecondsSince1970
        case .iso8601: return .iso8601
        case .formatted(let formatter): return .formatted(formatter)
        case .automatic: return .secondsSince1970
        }
    }
}

/// keyed 编码容器：把字段写入对象节点，key 经 `encodedKey` 归一化
struct FlexibleKeyedEncoder<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: FlexibleEncoderImpl
    var codingPath: [CodingKey] { encoder.codingPath }

    /// 以下标量编码：直接把对应类型写入节点（nil/布尔/字符串/数字）
    mutating func encodeNil(forKey key: Key) throws { write(key, .null) }
    mutating func encode(_ value: Bool, forKey key: Key) throws { write(key, .bool(value)) }
    mutating func encode(_ value: String, forKey key: Key) throws { write(key, .string(value)) }
    mutating func encode(_ value: Double, forKey key: Key) throws { write(key, try encoder.numberNode(value)) }
    mutating func encode(_ value: Float, forKey key: Key) throws { write(key, try encoder.numberNode(value)) }
    mutating func encode(_ value: Int, forKey key: Key) throws { write(key, .number(NSNumber(value: value))) }
    mutating func encode(_ value: Int8, forKey key: Key) throws { write(key, .number(NSNumber(value: value))) }
    mutating func encode(_ value: Int16, forKey key: Key) throws { write(key, .number(NSNumber(value: value))) }
    mutating func encode(_ value: Int32, forKey key: Key) throws { write(key, .number(NSNumber(value: value))) }
    mutating func encode(_ value: Int64, forKey key: Key) throws { write(key, .number(NSNumber(value: value))) }
    mutating func encode(_ value: UInt, forKey key: Key) throws { write(key, .number(NSNumber(value: value))) }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { write(key, .number(NSNumber(value: value))) }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { write(key, .number(NSNumber(value: value))) }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { write(key, .number(NSNumber(value: value))) }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { write(key, .number(NSNumber(value: value))) }

    /// 通用字段编码：依次处理忽略字段、展平字段、值转换、日期，最后走嵌套编码
    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        // 被忽略字段：默认跳过，显式开启时才输出
        if let ignored = value as? ZHHJSONIgnoredMarker {
            guard encoder.includeIgnoredValues else { return }
            let childBox = JSONNodeBox()
            let child = encoder.childEncoder(box: childBox, key: key, type: T.self)
            try ignored.encodeIgnoredValue(to: child)
            write(key, childBox.node)
            return
        }
        // 展平字段：把内容平铺到当前对象，不嵌套
        if value is ZHHJSONFlatMarker {
            try value.encode(to: encoder)
            return
        }
        // 命中值转换器时用转换结果输出
        if let transformer = encoder.valueMaps[key.stringValue], let json = transformer.toJSON(value) {
            write(key, JSONNode.from(json))
            return
        }
        // 日期走统一策略
        if let date = value as? Date {
            write(key, encoder.dateNode(date))
            return
        }
        let childBox = JSONNodeBox()
        let child = encoder.childEncoder(box: childBox, key: key, type: T.self)
        try value.encode(to: child)
        write(key, childBox.node)
    }

    /// 嵌套对象编码容器；子结果通过回调写回父节点
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let parentEncoder = encoder
        let parentKey = key
        let childBox = JSONNodeBox(node: .object([:])) { node in
            let parent = FlexibleKeyedEncoder<Key>(encoder: parentEncoder)
            parent.write(parentKey, node)
        }
        write(key, childBox.node)
        return KeyedEncodingContainer(FlexibleKeyedEncoder<NestedKey>(encoder: encoder.childEncoder(box: childBox, key: key, type: Any.self)))
    }

    /// 嵌套数组编码容器；子结果通过回调写回父节点
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let parentEncoder = encoder
        let parentKey = key
        let childBox = JSONNodeBox(node: .array([])) { node in
            let parent = FlexibleKeyedEncoder<Key>(encoder: parentEncoder)
            parent.write(parentKey, node)
        }
        write(key, childBox.node)
        return FlexibleUnkeyedEncoder(encoder: encoder.childEncoder(box: childBox, key: key, type: Any.self))
    }

    /// 父类编码器；写入键固定为 super
    mutating func superEncoder() -> Encoder {
        let parentEncoder = encoder
        let childBox = JSONNodeBox { node in
            let parent = FlexibleKeyedEncoder<Key>(encoder: parentEncoder)
            parent.write(property: "super", node)
        }
        write(property: "super", childBox.node)
        return encoder.childEncoder(box: childBox, key: AnyCodingKey(stringValue: "super"), type: Any.self)
    }

    /// 指定 key 的父类编码器
    mutating func superEncoder(forKey key: Key) -> Encoder {
        let parentEncoder = encoder
        let parentKey = key
        let childBox = JSONNodeBox { node in
            let parent = FlexibleKeyedEncoder<Key>(encoder: parentEncoder)
            parent.write(parentKey, node)
        }
        write(key, childBox.node)
        return encoder.childEncoder(box: childBox, key: key, type: Any.self)
    }

    /// 用 CodingKey 写入节点
    private func write(_ key: Key, _ node: JSONNode) {
        write(property: key.stringValue, node)
    }

    /// 把节点写入对象；key 含 `.` 时按路径展开（支持 a.b.0.c）
    private func write(property: String, _ node: JSONNode) {
        let jsonKey = encoder.encodedKey(for: property)
        var object: [String: JSONNode] = [:]
        if case .object(let current) = encoder.box.node { object = current }
        if jsonKey.contains(".") {
            encoder.box.node = setValue(
                node,
                at: jsonKey.split(separator: ".").map(String.init),
                in: .object(object)
            )
            return
        }
        object[jsonKey] = node
        encoder.box.node = .object(object)
    }

    /// 按路径递归写入；数字段视为数组下标，缺失的中间层自动补 null/空结构
    private func setValue(_ value: JSONNode, at path: [String], in node: JSONNode) -> JSONNode {
        guard let first = path.first else { return node }
        if path.count == 1 {
            if let index = Int(first) {
                var array = array(from: node)
                expand(&array, through: index)
                array[index] = value
                return .array(array)
            }
            var object = object(from: node)
            object[first] = value
            return .object(object)
        }

        if let index = Int(first) {
            var array = array(from: node)
            expand(&array, through: index)
            array[index] = setValue(value, at: Array(path.dropFirst()), in: array[index])
            return .array(array)
        }

        var object = object(from: node)
        object[first] = setValue(value, at: Array(path.dropFirst()), in: object[first] ?? .null)
        return .object(object)
    }

    /// 取节点的对象内容，非对象返回空字典
    private func object(from node: JSONNode) -> [String: JSONNode] {
        if case .object(let object) = node { return object }
        return [:]
    }

    /// 取节点的数组内容，非数组返回空数组
    private func array(from node: JSONNode) -> [JSONNode] {
        if case .array(let array) = node { return array }
        return []
    }

    /// 把数组扩展到指定下标，缺失位置补 null
    private func expand(_ array: inout [JSONNode], through index: Int) {
        while array.count <= index {
            array.append(.null)
        }
    }

}

/// unkeyed 编码容器：把元素依次追加到数组节点
struct FlexibleUnkeyedEncoder: UnkeyedEncodingContainer {
    let encoder: FlexibleEncoderImpl
    var codingPath: [CodingKey] { encoder.codingPath }
    var count: Int {
        if case .array(let array) = encoder.box.node { return array.count }
        return 0
    }

    /// 以下标量编码：直接把对应类型追加到数组节点
    mutating func encodeNil() throws { append(.null) }
    mutating func encode(_ value: Bool) throws { append(.bool(value)) }
    mutating func encode(_ value: String) throws { append(.string(value)) }
    mutating func encode(_ value: Double) throws { append(try encoder.numberNode(value)) }
    mutating func encode(_ value: Float) throws { append(try encoder.numberNode(value)) }
    mutating func encode(_ value: Int) throws { append(.number(NSNumber(value: value))) }
    mutating func encode(_ value: Int8) throws { append(.number(NSNumber(value: value))) }
    mutating func encode(_ value: Int16) throws { append(.number(NSNumber(value: value))) }
    mutating func encode(_ value: Int32) throws { append(.number(NSNumber(value: value))) }
    mutating func encode(_ value: Int64) throws { append(.number(NSNumber(value: value))) }
    mutating func encode(_ value: UInt) throws { append(.number(NSNumber(value: value))) }
    mutating func encode(_ value: UInt8) throws { append(.number(NSNumber(value: value))) }
    mutating func encode(_ value: UInt16) throws { append(.number(NSNumber(value: value))) }
    mutating func encode(_ value: UInt32) throws { append(.number(NSNumber(value: value))) }
    mutating func encode(_ value: UInt64) throws { append(.number(NSNumber(value: value))) }

    /// 通用元素编码：日期走统一策略，其余走嵌套编码后追加
    mutating func encode<T: Encodable>(_ value: T) throws {
        if let date = value as? Date {
            append(encoder.dateNode(date))
            return
        }
        let childBox = JSONNodeBox()
        let child = encoder.childEncoder(box: childBox, key: nil, type: T.self)
        try value.encode(to: child)
        append(childBox.node)
    }

    /// 嵌套对象编码容器；子结果通过 replace 写回指定下标
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let index = count
        let parentEncoder = encoder
        let childBox = JSONNodeBox(node: .object([:])) { node in
            parentEncoder.replace(node, at: index)
        }
        append(childBox.node)
        return KeyedEncodingContainer(FlexibleKeyedEncoder<NestedKey>(encoder: encoder.childEncoder(box: childBox, key: nil, type: Any.self)))
    }

    /// 嵌套数组编码容器
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let index = count
        let parentEncoder = encoder
        let childBox = JSONNodeBox(node: .array([])) { node in
            parentEncoder.replace(node, at: index)
        }
        append(childBox.node)
        return FlexibleUnkeyedEncoder(encoder: encoder.childEncoder(box: childBox, key: nil, type: Any.self))
    }

    /// 父类编码器；结果写回当前下标
    mutating func superEncoder() -> Encoder {
        let index = count
        let parentEncoder = encoder
        let childBox = JSONNodeBox { node in
            parentEncoder.replace(node, at: index)
        }
        append(childBox.node)
        return encoder.childEncoder(box: childBox, key: AnyCodingKey(intValue: index), type: Any.self)
    }

    /// 向数组节点追加一个元素
    private func append(_ node: JSONNode) {
        var array: [JSONNode] = []
        if case .array(let current) = encoder.box.node { array = current }
        array.append(node)
        encoder.box.node = .array(array)
    }
}

/// 单值编码容器：把标量直接写入节点
struct FlexibleSingleValueEncoder: SingleValueEncodingContainer {
    let encoder: FlexibleEncoderImpl
    var codingPath: [CodingKey] { encoder.codingPath }

    /// 以下标量编码：直接把对应类型写入节点
    mutating func encodeNil() throws { encoder.box.node = .null }
    mutating func encode(_ value: Bool) throws { encoder.box.node = .bool(value) }
    mutating func encode(_ value: String) throws { encoder.box.node = .string(value) }
    mutating func encode(_ value: Double) throws { encoder.box.node = try encoder.numberNode(value) }
    mutating func encode(_ value: Float) throws { encoder.box.node = try encoder.numberNode(value) }
    mutating func encode(_ value: Int) throws { encoder.box.node = .number(NSNumber(value: value)) }
    mutating func encode(_ value: Int8) throws { encoder.box.node = .number(NSNumber(value: value)) }
    mutating func encode(_ value: Int16) throws { encoder.box.node = .number(NSNumber(value: value)) }
    mutating func encode(_ value: Int32) throws { encoder.box.node = .number(NSNumber(value: value)) }
    mutating func encode(_ value: Int64) throws { encoder.box.node = .number(NSNumber(value: value)) }
    mutating func encode(_ value: UInt) throws { encoder.box.node = .number(NSNumber(value: value)) }
    mutating func encode(_ value: UInt8) throws { encoder.box.node = .number(NSNumber(value: value)) }
    mutating func encode(_ value: UInt16) throws { encoder.box.node = .number(NSNumber(value: value)) }
    mutating func encode(_ value: UInt32) throws { encoder.box.node = .number(NSNumber(value: value)) }
    mutating func encode(_ value: UInt64) throws { encoder.box.node = .number(NSNumber(value: value)) }

    /// 通用编码：日期走统一策略，其余直接编码到节点
    mutating func encode<T: Encodable>(_ value: T) throws {
        if let date = value as? Date {
            encoder.box.node = encoder.dateNode(date)
            return
        }
        try value.encode(to: encoder)
    }
}
