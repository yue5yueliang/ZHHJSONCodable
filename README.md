# ZHHJSONCodable

基于原生 `Codable` 的柔性 JSON 库。缺字段回落 `init()` 初始值，类型不匹配、脏数组、字符串套 JSON 时尽量解出模型。

## 安装

```ruby
pod 'ZHHJSONCodable'
```

最低 iOS 15.0。class 需提供 `required init()`；struct 属性带默认值即可。

## 用法

```swift
import ZHHJSONCodable

struct User: ZHHJSONCodable {
    var id: Int64 = 0
    var name: String = ""
    var age: Int = 2
    var vip: Bool = false

    static func keyMapping() -> [ZHHJSONKeyMap] {
        [ZHHJSONKeyMap(CodingKeys.id, "user_id", "userId", "id")]
    }
}

let user = try User.decode(from: #"{"user_id":"9","name":2026}"#)
// age 仍是 2
let list = try [User].decode(from: data)
let users = try [String: User].decode(from: json)
let nested = try User.decode(from: json, path: "data.list.0")
let text = try user.encodeJSONString()
let optional = User.decodeIfPresent(from: raw)
```

```swift
try ZHHJSONUpdater.update(&user, from: #"{"userId":2,"name":"新名字"}"#)
try ZHHJSONUpdater.update(
    &user,
    from: patch,
    decodeOptions: ZHHJSONDecodeOptions(dateStrategy: .millisecondsSince1970)
)
ZHHJSONUpdater.updateIfPresent(&user, from: patch)
```

跨层 key、日期、颜色：

```swift
struct Profile: ZHHJSONCodable {
    var name: String = ""
    @ZHHJSONDate var createdAt: Date?
    @ZHHJSONHexColor var color: UIColor?
    @ZHHJSONAny var extra: [String: Any] = [:]

    static func keyMapping() -> [ZHHJSONKeyMap] {
        [ZHHJSONKeyMap(CodingKeys.name, "user.nick", "nick")]
    }
}

let options = ZHHJSONDecodeOptions(dateStrategy: .automatic, emptyStringAsNil: true, logContext: "profile")
let profile = try Profile.decode(from: json, options: options)
```

## 能力

- 缺字段 / null 回落 **属性在 `init()` 里声明的初始值**（含 class 父类、属性包装器、`Optional` 的 `nil`）
- `decode` / `encodeData` / `encodeObject` / `encodeJSONString` 失败会抛错；`*IfPresent` 返回 `Optional`
- 模型、`[Model]`、`[String: Model]` 入口对称
- Key 映射用 `CodingKeys`，改属性名会编译失败；支持 `a.b.0.c`、蛇形命名、路径下钻
- 数组 / 字典跳过脏元素；字段类型不是数组 / 字典时回落初始值
- 字符串套 JSON、顶层单值 JSON（`18` / `"hi"` / `true`）
- 枚举非法值回落第一个 case（`ZHHJSONEnum`）
- 值转换：Date / URL / Data / HexColor / `CGFloat` / `Decimal` / 自定义 `ZHHJSONFastTransform`
- `Optional` 同样走 `valueMapping`；空字符串默认当 `nil`（`emptyStringAsNil`）
- 数字越界、`nan` / `inf` 不 trap、不截成错值，回落初始值
- 增量更新：`ZHHJSONUpdater` 递归合并，顶层和嵌套对象都认 key 映射别名，并接受编解码选项
- `@ZHHJSONIgnored` / `@ZHHJSONAny` / `@ZHHJSONFlat` / `@ZHHJSONDate` / `@ZHHJSONHexColor`
- 结构化日志 + `logHandler`
- 仍可用原生 `JSONDecoder` + `decodeFlexibleIfPresent`

```swift
ZHHJSONConfiguration.isLogEnabled = true
ZHHJSONConfiguration.logHandler = { print($0) }
```

## License

MIT
