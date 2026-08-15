//
//  ZHHJSONConfiguration.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import Foundation

/// 解码日志开关与输出控制：用于在排查缺字段/类型不匹配等回落行为时拿到结构化记录
public enum ZHHJSONConfiguration {
    /// 保护 `enabled` / `handler` 读写的线程锁
    private static let lock = NSLock()
    /// 是否开启结构化日志（默认关闭）
    private static var enabled = false
    /// 自定义日志出口；为 nil 时回落 `print`
    private static var handler: ((String) -> Void)?

    /// 为 `true` 时，一次解码结束后打印结构化日志（默认关闭）
    public static var isLogEnabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return enabled
        }
        set {
            lock.lock()
            enabled = newValue
            lock.unlock()
        }
    }

    /// 自定义日志出口；为 nil 时走 `print`
    public static var logHandler: ((String) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return handler
        }
        set {
            lock.lock()
            handler = newValue
            lock.unlock()
        }
    }

    /// 输出日志：有自定义 handler 则走 handler，否则回落 print
    static func emit(_ message: String) {
        let output: ((String) -> Void)?
        lock.lock()
        output = handler
        lock.unlock()
        if let output {
            output(message)
        } else {
            print(message)
        }
    }
}

/// 单次解码的日志收集器：记录每处「回落」动作，结束时一次性输出
final class ZHHJSONLogSession {
    let typeName: String
    let context: String?
    private var items: [Item] = []

    struct Item {
        let path: String
        let expected: String
        let actual: String
        let action: String
    }

    /// 初始化日志会话，记录类型名与上下文
    init(typeName: String, context: String?) {
        self.typeName = typeName
        self.context = context
    }

    /// 记录一次回落；日志关闭时直接丢弃，不产生开销
    func record(path: [CodingKey], expected: String, actual: String, action: String) {
        guard ZHHJSONConfiguration.isLogEnabled else { return }
        // 数组下标转 [n]，其余用 key 名，点号拼接成可读路径
        let text = path.map { key -> String in
            if let index = key.intValue { return "[\(index)]" }
            return key.stringValue
        }.joined(separator: ".")
        items.append(Item(path: text.isEmpty ? "(root)" : text, expected: expected, actual: actual, action: action))
    }

    /// 输出汇总日志；无记录或日志关闭时静默返回
    func flush() {
        guard ZHHJSONConfiguration.isLogEnabled, !items.isEmpty else { return }
        var lines: [String] = []
        if let context, !context.isEmpty {
            lines.append("ZHHJSONCodable: \(context)")
        }
        lines.append("ZHHJSONCodable: 解码 \(typeName)，\(items.count) 处回落")
        for item in items {
            lines.append("  - \(item.path): 期望 \(item.expected)，实际 \(item.actual)，\(item.action)")
        }
        ZHHJSONConfiguration.emit(lines.joined(separator: "\n"))
    }
}
