//
//  DefaultValueCache.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  从当前 init() 模板读取属性初始值，含父类、包装器和 Optional.none。
//

import Foundation

/// 从当前 `init()` 模板读取属性初始值，供缺失字段回落使用
///
/// 用反射把模板的属性名/值/是否 present 摊平，覆盖父类、属性包装器与 Optional.none
enum DefaultValueCache {
    struct Box {
        /// 原始属性名（含下划线前缀）到值的映射
        let raw: [String: Any]
        /// 属性包装器 `wrappedValue` 到值的映射
        let wrapped: [String: Any]
        /// 所有出现过的属性名（含下划线前缀），用于区分「缺字段」与「值为 nil」
        let present: Set<String>
    }

    /// 查某属性的默认值：优先原始值，其次包装值，最后按是否 present 区分 nil
    static func lookup<T>(_ : T.Type, property: String, template: Any) -> (found: Bool, value: T?) {
        let box = cached(template)
        if let value = box.raw[property] as? T { return (true, value) }
        if let value = box.wrapped[property] as? T { return (true, value) }
        if let value = box.raw["_" + property] as? T { return (true, value) }
        if box.present.contains(property) || box.present.contains("_" + property) {
            return (true, nil)
        }
        return (false, nil)
    }

    /// 构建模板的属性快照；每次调用都重新反射，不跨会话复用
    static func cached(_ template: Any) -> Box {
        // 模板由当前解码会话的 init() 创建。不能按类型缓存属性值：Date、UUID
        // 和引用类型属性都可能在每次 init() 时不同，复用会改变默认值语义。
        build(template)
    }

    /// 用反射沿继承链摊平模板的所有属性
    private static func build(_ template: Any) -> Box {
        var raw: [String: Any] = [:]
        var wrapped: [String: Any] = [:]
        var present: Set<String> = []
        var mirror: Mirror? = Mirror(reflecting: template)
        while let current = mirror {
            for child in current.children {
                guard let label = child.label else { continue }
                let name = label.hasPrefix("_") ? String(label.dropFirst()) : label
                present.insert(label)
                present.insert(name)
                if !isNil(child.value) {
                    raw[label] = child.value
                    raw[name] = child.value
                }
                // 属性包装器同时记录 wrappedValue
                if let inner = wrappedValue(of: child.value) {
                    present.insert(name)
                    if !isNil(inner) {
                        wrapped[name] = inner
                    }
                }
            }
            mirror = current.superclassMirror
        }
        return Box(raw: raw, wrapped: wrapped, present: present)
    }

    /// 判断是否为 nil 的 Optional
    private static func isNil(_ value: Any) -> Bool {
        let mirror = Mirror(reflecting: value)
        return mirror.displayStyle == .optional && mirror.children.isEmpty
    }

    /// 提取属性包装器的 wrappedValue
    private static func wrappedValue(of value: Any) -> Any? {
        Mirror(reflecting: value).children.first(where: { $0.label == "wrappedValue" })?.value
    }
}
