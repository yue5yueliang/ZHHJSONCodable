//
//  ZHHJSONDecodeError.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import Foundation

/// 解码错误类型：区分「输入空 / JSON 非法 / 路径不存在 / 解码失败」四类
public enum ZHHJSONDecodeError: Error {
    /// Data / String / 对象为 nil 或空
    case emptyInput
    /// 不是合法 JSON
    case invalidJSON(underlying: Error)
    /// `path` 在 JSON 里不存在
    case pathNotFound(String)
    /// JSON 合法，但模型解码失败
    case failed(underlying: Error)
}

extension ZHHJSONDecodeError: LocalizedError {
    /// 各类错误的用户可读文案
    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "输入为空"
        case .invalidJSON(let error):
            return "JSON 无效: \(error.localizedDescription)"
        case .pathNotFound(let path):
            return "路径不存在: \(path)"
        case .failed(let error):
            return "解码失败: \(error.localizedDescription)"
        }
    }
}

/// 把任意解码错误统一规整为 `ZHHJSONDecodeError`，并补充 path 上下文
enum ZHHJSONDecodeErrorMapper {
    static func map(_ error: Error, path: String?) -> ZHHJSONDecodeError {
        // 已是本库错误则原样返回
        if let typed = error as? ZHHJSONDecodeError { return typed }
        // 原生 DecodingError 中路径缺失的场景，识别为 pathNotFound
        if let decoding = error as? DecodingError, case .dataCorrupted(let context) = decoding,
           context.debugDescription.hasPrefix("路径不存在") {
            return .pathNotFound(path ?? "")
        }
        // 其余统一兜底为 failed
        return .failed(underlying: error)
    }
}
