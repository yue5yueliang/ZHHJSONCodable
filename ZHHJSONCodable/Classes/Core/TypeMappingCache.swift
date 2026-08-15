//
//  TypeMappingCache.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//
//  按类型缓存 key / value 映射，class 会合并父类。
//

import Foundation

/// 按类型缓存 key/value 映射；class 会沿继承链合并父类映射
enum TypeMappingCache {
    private static let lock = NSLock()
    private static var keys: [ObjectIdentifier: [String: [String]]] = [:]
    private static var values: [ObjectIdentifier: [String: any ZHHJSONTransforming]] = [:]

    /// 取类型的 key 映射，命中缓存直接返回，未命中则构建并缓存
    static func keyMaps(for type: Any.Type) -> [String: [String]] {
        let identifier = ObjectIdentifier(type)
        lock.lock()
        if let cached = keys[identifier] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        var result: [String: [String]] = [:]
        // 子类优先：同属性名已被占用则忽略父类定义
        for mapped in mappedTypes(from: type) {
            for item in mapped.keyMapping() where result[item.propertyName] == nil {
                result[item.propertyName] = item.jsonKeys
            }
        }
        lock.lock()
        keys[identifier] = result
        lock.unlock()
        return result
    }

    /// 取类型的值映射，逻辑同 keyMaps
    static func valueMaps(for type: Any.Type) -> [String: any ZHHJSONTransforming] {
        let identifier = ObjectIdentifier(type)
        lock.lock()
        if let cached = values[identifier] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        var result: [String: any ZHHJSONTransforming] = [:]
        for mapped in mappedTypes(from: type) {
            for item in mapped.valueMapping() where result[item.propertyName] == nil {
                result[item.propertyName] = item.transformer
            }
        }
        lock.lock()
        values[identifier] = result
        lock.unlock()
        return result
    }

    /// 收集类型及其所有父类中符合 `ZHHJSONCodable` 的映射类型（子类在前）
    private static func mappedTypes(from type: Any.Type) -> [any ZHHJSONCodable.Type] {
        var result: [any ZHHJSONCodable.Type] = []
        if let cls = type as? AnyClass {
            var current: AnyClass? = cls
            while let item = current {
                if let mapped = item as? any ZHHJSONCodable.Type {
                    result.append(mapped)
                }
                current = class_getSuperclass(item)
            }
        } else if let mapped = type as? any ZHHJSONCodable.Type {
            result.append(mapped)
        }
        return result
    }
}
