//
//  Tests.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import XCTest
import UIKit
import ZHHJSONCodable

private enum Sex: String, ZHHJSONEnum {
    case man
    case woman
}

private struct User: ZHHJSONCodable {
    var id: Int64 = 0
    var name: String = ""
    var age: Int = 2
    var vip: Bool = false
    var sex: Sex = .man

    static func keyMapping() -> [ZHHJSONKeyMap] {
        [ZHHJSONKeyMap(CodingKeys.id, "user_id", "userId", "id")]
    }
}

private struct Wrapper: ZHHJSONCodable {
    var user: User = User()
}

private struct Dated: ZHHJSONCodable {
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    static func valueMapping() -> [ZHHJSONValueMap] {
        [ZHHJSONValueMap(CodingKeys.createdAt, ZHHJSONDateTransform(.secondsSince1970))]
    }
}

private struct CacheModel: ZHHJSONCodable {
    var name: String = ""
    @ZHHJSONIgnored var token: String = "local"
}

private struct FlexibleSample: Decodable {
    let id: Int64?
    let count: Int?

    enum CodingKeys: String, CodingKey { case id, count }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleIfPresent(Int64.self, forKey: .id)
        count = container.decodeFlexibleIfPresent(Int.self, forKey: .count)
    }
}

final class Tests: XCTestCase {

    func testNativeJSONDecoderHelper() throws {
        let sample = try JSONDecoder().decode(FlexibleSample.self, from: Data(#"{"id":"1001","count":3}"#.utf8))
        XCTAssertEqual(sample.id, 1001)
        XCTAssertEqual(sample.count, 3)
    }

    func testDecodeTypeMismatch() {
        let user = User.decodeIfPresent(from: #"{"id":"9","name":2026,"age":"18","vip":"1"}"#)
        XCTAssertEqual(user?.id, 9)
        XCTAssertEqual(user?.name, "2026")
        XCTAssertEqual(user?.age, 18)
        XCTAssertEqual(user?.vip, true)
    }

    func testPropertyInitialValue() {
        let user = User.decodeIfPresent(from: #"{"name":"张三"}"#)
        XCTAssertEqual(user?.id, 0)
        XCTAssertEqual(user?.name, "张三")
        XCTAssertEqual(user?.age, 2)
        XCTAssertEqual(user?.vip, false)
    }

    func testKeyMapping() {
        let user = User.decodeIfPresent(from: #"{"user_id":88,"name":"A"}"#)
        XCTAssertEqual(user?.id, 88)
    }

    func testEnumFallback() {
        let user = User.decodeIfPresent(from: #"{"sex":"unknown"}"#)
        XCTAssertEqual(user?.sex, .man)
        let woman = User.decodeIfPresent(from: #"{"sex":"woman"}"#)
        XCTAssertEqual(woman?.sex, .woman)
    }

    func testSnakeCaseStrategy() throws {
        struct Book: Decodable {
            var pageCount: Int
        }
        let decoder = FlexibleJSONDecoder()
        decoder.keyStrategy = .convertFromSnakeCase
        let book = try decoder.decode(Book.self, from: #"{"page_count":12}"#)
        XCTAssertEqual(book.pageCount, 12)
    }

    func testDesignatedPath() {
        let user = User.decodeIfPresent(from: #"{"data":{"user":{"id":7,"name":"B"}}}"#, path: "data.user")
        XCTAssertEqual(user?.id, 7)
        XCTAssertEqual(user?.name, "B")
    }

    func testCompactArray() {
        let list = [User].decodeIfPresent(from: #"[{"id":1,"name":"A"},"bad",{"id":"2","name":"B"}]"#)
        XCTAssertEqual(list?.count, 2)
        XCTAssertEqual(list?.last?.id, 2)
    }

    func testCompactDictionary() throws {
        struct Box: ZHHJSONCodable {
            var map: [String: Int] = [:]
        }
        let box = Box.decodeIfPresent(from: #"{"map":{"a":1,"b":"x","c":"3"}}"#)
        XCTAssertEqual(box?.map["a"], 1)
        XCTAssertEqual(box?.map["c"], 3)
        XCTAssertNil(box?.map["b"])
    }

    func testStringifiedJSON() {
        let wrapper = Wrapper.decodeIfPresent(from: #"{"user":"{\"id\":3,\"name\":\"C\"}"}"#)
        XCTAssertEqual(wrapper?.user.id, 3)
        XCTAssertEqual(wrapper?.user.name, "C")
    }

    func testDateTransform() {
        let dated = Dated.decodeIfPresent(from: #"{"createdAt":1700000000}"#)
        XCTAssertEqual(dated?.createdAt.timeIntervalSince1970, 1_700_000_000)
    }

    func testIgnoredKeepsInitial() {
        let model = CacheModel.decodeIfPresent(from: #"{"name":"N","token":"remote"}"#)
        XCTAssertEqual(model?.name, "N")
        XCTAssertEqual(model?.token, "local")
    }

    func testEncodeAndUpdate() throws {
        var user = User.decodeIfPresent(from: #"{"id":1,"name":"A","age":9}"#)!
        XCTAssertNotNil(try? user.encodeJSONString())
        try ZHHJSONUpdater.update(&user, from: #"{"name":"B"}"#)
        XCTAssertEqual(user.name, "B")
        XCTAssertEqual(user.age, 9)
        XCTAssertEqual(user.id, 1)
    }

    func testKeyPathMapping() {
        struct Profile: ZHHJSONCodable {
            var name: String = ""

            static func keyMapping() -> [ZHHJSONKeyMap] {
                [ZHHJSONKeyMap(CodingKeys.name, "user.nick", "nick", "name")]
            }
        }
        let profile = Profile.decodeIfPresent(from: #"{"user":{"nick":"小明"}}"#)
        XCTAssertEqual(profile?.name, "小明")
        let json = (try? profile?.encodeJSONString()) ?? nil
        XCTAssertTrue(json?.contains("小明") == true)
    }

    func testPathWithArrayIndex() {
        let user = User.decodeIfPresent(from: #"{"list":[{"id":1},{"id":8,"name":"D"}]}"#, path: "list.1")
        XCTAssertEqual(user?.id, 8)
        XCTAssertEqual(user?.name, "D")
    }

    func testRecursiveUpdate() throws {
        struct Address: ZHHJSONCodable {
            var city: String = ""
            var street: String = ""
        }
        struct Person: ZHHJSONCodable {
            var name: String = ""
            var address: Address = Address()
        }
        var person = Person.decodeIfPresent(from: #"{"name":"A","address":{"city":"北京","street":"一号"}}"#)!
        try ZHHJSONUpdater.update(&person, from: #"{"address":{"city":"上海"}}"#)
        XCTAssertEqual(person.name, "A")
        XCTAssertEqual(person.address.city, "上海")
        XCTAssertEqual(person.address.street, "一号")
    }

    func testAutomaticDateAndDecimal() {
        struct Payload: ZHHJSONCodable {
            var createdAt: Date = Date(timeIntervalSince1970: 0)
            var amount: Decimal = 0
            var width: CGFloat = 0
        }
        let decoder = FlexibleJSONDecoder()
        decoder.dateStrategy = .automatic
        let payload = try? decoder.decode(
            Payload.self,
            from: #"{"createdAt":1577932245,"amount":"12.5","width":"9"}"#
        )
        XCTAssertEqual(payload?.amount, Decimal(string: "12.5"))
        XCTAssertEqual(payload?.width, 9)
        XCTAssertEqual(payload?.createdAt.timeIntervalSince1970, 1_577_932_245)
    }

    func testDateWrapper() {
        struct Payload: ZHHJSONCodable {
            @ZHHJSONDate var createdAt: Date?
        }
        let payload = Payload.decodeIfPresent(from: #"{"createdAt":1700000000000}"#)
        XCTAssertEqual(payload?.createdAt?.timeIntervalSince1970, 1_700_000_000)
    }

    func testAnyDictionaryAndArray() {
        struct Box: ZHHJSONCodable {
            @ZHHJSONAny var extra: [String: Any] = [:]
            @ZHHJSONAny var tags: [Any] = []
        }
        let box = Box.decodeIfPresent(from: #"{"extra":{"a":1,"b":"x"},"tags":[1,"ok",true]}"#)
        XCTAssertEqual(box?.extra["a"] as? Int, 1)
        XCTAssertEqual(box?.extra["b"] as? String, "x")
        XCTAssertEqual(box?.tags.count, 3)
    }

    func testHexColor() {
        struct Theme: ZHHJSONCodable {
            @ZHHJSONHexColor var color: UIColor?
        }
        let theme = Theme.decodeIfPresent(from: ##"{"color":"#FF0000"}"##)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        theme?.color?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1, accuracy: 0.01)
        XCTAssertEqual(g, 0, accuracy: 0.01)
        XCTAssertEqual(b, 0, accuracy: 0.01)
    }

    func testFlatEncodeAndDidFinish() {
        struct Address: ZHHJSONCodable {
            var city: String = ""
            var display: String = ""

            mutating func didFinishMapping() {
                display = city + "市"
            }
        }
        struct Person: ZHHJSONCodable {
            var name: String = ""
            @ZHHJSONFlat var address: Address = Address()
        }
        let person = Person.decodeIfPresent(from: #"{"name":"A","city":"杭州"}"#)
        XCTAssertEqual(person?.address.city, "杭州")
        XCTAssertEqual(person?.address.display, "杭州市")
        let json = (try? person?.encodeJSONString()) ?? nil
        XCTAssertTrue(json?.contains("杭州") == true)
        XCTAssertTrue(json?.contains("\"name\"") == true)
    }

    func testEncodeMappedKeysAndArray() {
        let user = User.decodeIfPresent(from: #"{"user_id":3,"name":"A"}"#)!
        let mapped = try? user.encodeJSONString(options: ZHHJSONEncodeOptions(useMappedKeys: true))
        XCTAssertTrue(mapped?.contains("user_id") == true)
        let raw = try? user.encodeJSONString(options: ZHHJSONEncodeOptions(useMappedKeys: false))
        XCTAssertTrue(raw?.contains("\"id\"") == true)
        let list = try? [user].encodeJSONString()
        XCTAssertTrue(list?.hasPrefix("[") == true)
    }

    func testStructuredLog() {
        var messages: [String] = []
        ZHHJSONConfiguration.isLogEnabled = true
        ZHHJSONConfiguration.logHandler = { messages.append($0) }
        _ = User.decodeIfPresent(from: #"{"age":"bad"}"#)
        ZHHJSONConfiguration.isLogEnabled = false
        ZHHJSONConfiguration.logHandler = nil
        XCTAssertTrue(messages.contains(where: { $0.contains("age") }))
    }

    func testDecodeErrorDistinction() {
        XCTAssertThrowsError(try User.decode(from: nil as String?)) { error in
            guard case ZHHJSONDecodeError.emptyInput = error else {
                return XCTFail("期望 emptyInput，实际 \(error)")
            }
        }
        XCTAssertThrowsError(try User.decode(from: "{")) { error in
            guard case ZHHJSONDecodeError.invalidJSON = error else {
                return XCTFail("期望 invalidJSON，实际 \(error)")
            }
        }
        XCTAssertThrowsError(try User.decode(from: #"{"id":1}"#, path: "missing")) { error in
            guard case ZHHJSONDecodeError.pathNotFound(let path) = error else {
                return XCTFail("期望 pathNotFound，实际 \(error)")
            }
            XCTAssertEqual(path, "missing")
        }
        XCTAssertNil(User.decodeIfPresent(from: nil as String?))
        XCTAssertNil(User.decodeIfPresent(from: "{"))
    }

    func testEncodeFragment() throws {
        let data = try FlexibleJSONEncoder().encode("hello")
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"hello\"")
        let number = try FlexibleJSONEncoder().encode(12)
        XCTAssertEqual(String(data: number, encoding: .utf8), "12")
    }

    func testClassAndWrapperDefaults() {
        class Account: ZHHJSONCodable {
            var age: Int = 2
            @ZHHJSONIgnored var token: String = "local"
            required init() {}
        }
        class VIPAccount: Account {
            var level: Int = 3
            required init() { super.init() }
            required init(from decoder: Decoder) throws {
                level = 3
                try super.init(from: decoder)
            }
        }
        let account = Account.decodeIfPresent(from: #"{"token":"remote"}"#)
        XCTAssertEqual(account?.age, 2)
        XCTAssertEqual(account?.token, "local")
        let vip = VIPAccount.decodeIfPresent(from: #"{}"#)
        XCTAssertEqual(vip?.age, 2)
        XCTAssertEqual(vip?.level, 3)
        XCTAssertEqual(vip?.token, "local")
    }

    func testUpdateErrorAndIfPresent() {
        var user = User()
        XCTAssertThrowsError(try ZHHJSONUpdater.update(&user, from: nil as String?)) { error in
            guard case ZHHJSONUpdateError.emptyInput = error else {
                return XCTFail("期望 emptyInput，实际 \(error)")
            }
        }
        XCTAssertFalse(ZHHJSONUpdater.updateIfPresent(&user, from: "{"))
        XCTAssertTrue(ZHHJSONUpdater.updateIfPresent(&user, from: #"{"name":"C"}"#))
        XCTAssertEqual(user.name, "C")
    }

    func testDynamicDefaultsAreFreshForEveryDecode() {
        final class Reference: ZHHJSONCodable {
            var value = 0

            required init() {}
        }

        struct Payload: ZHHJSONCodable {
            var identifier = UUID().uuidString
            var reference = Reference()
        }

        let first = Payload.decodeIfPresent(from: #"{}"#)!
        let second = Payload.decodeIfPresent(from: #"{}"#)!
        XCTAssertNotEqual(first.identifier, second.identifier)
        XCTAssertFalse(first.reference === second.reference)
    }

    func testUpdaterPreservesIgnoredRuntimeValue() throws {
        struct Payload: ZHHJSONCodable {
            var name = ""
            @ZHHJSONIgnored var token = "local"
        }

        var payload = Payload()
        payload.token = "runtime-token"
        try ZHHJSONUpdater.update(&payload, from: #"{"name":"updated"}"#)
        XCTAssertEqual(payload.name, "updated")
        XCTAssertEqual(payload.token, "runtime-token")
    }

    func testNestedContainersWriteBackToParent() throws {
        struct Payload: Encodable {
            enum CodingKeys: String, CodingKey { case object, array }
            enum ObjectKeys: String, CodingKey { case name }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                var object = container.nestedContainer(keyedBy: ObjectKeys.self, forKey: .object)
                try object.encode("nested", forKey: .name)
                var array = container.nestedUnkeyedContainer(forKey: .array)
                var arrayObject = array.nestedContainer(keyedBy: ObjectKeys.self)
                try arrayObject.encode("item", forKey: .name)
            }
        }

        let object = try FlexibleJSONEncoder().encodeObject(Payload()) as? [String: Any]
        XCTAssertEqual((object?["object"] as? [String: Any])?["name"] as? String, "nested")
        XCTAssertEqual(((object?["array"] as? [[String: Any]])?.first)?["name"] as? String, "item")
    }

    func testSuperEncoderCreatesSeparateChildObject() throws {
        class Parent: Encodable {
            enum CodingKeys: String, CodingKey { case value }
            var parentValue = "parent"

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(parentValue, forKey: .value)
            }
        }

        final class Child: Parent {
            enum CodingKeys: String, CodingKey { case value, parent }
            var childValue = "child"

            override func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(childValue, forKey: .value)
                try super.encode(to: container.superEncoder(forKey: .parent))
            }
        }

        let object = try FlexibleJSONEncoder().encodeObject(Child()) as? [String: Any]
        XCTAssertEqual(object?["value"] as? String, "child")
        XCTAssertEqual((object?["parent"] as? [String: Any])?["value"] as? String, "parent")
    }

    func testKeyPathMappingEncodesArrayIndexes() throws {
        struct Profile: ZHHJSONCodable {
            var name = ""

            static func keyMapping() -> [ZHHJSONKeyMap] {
                [ZHHJSONKeyMap(CodingKeys.name, "users.0.name")]
            }
        }

        let object = try Profile(name: "A").encodeObject() as? [String: Any]
        let users = object?["users"] as? [[String: Any]]
        XCTAssertEqual(users?.count, 1)
        XCTAssertEqual(users?.first?["name"] as? String, "A")
    }

    func testOptionalDefaultsAndEmptyStringStrategy() {
        struct Payload: ZHHJSONCodable {
            var name: String? = "guest"
            var user: User? = User()
        }

        XCTAssertEqual(Payload.decodeIfPresent(from: #"{}"#)?.name, "guest")
        XCTAssertEqual(Payload.decodeIfPresent(from: #"{"name":null}"#)?.name, "guest")
        XCTAssertEqual(Payload.decodeIfPresent(from: #"{"name":""}"#)?.name, "guest")
        XCTAssertNotNil(Payload.decodeIfPresent(from: #"{}"#)?.user)

        let options = ZHHJSONDecodeOptions(emptyStringAsNil: false)
        XCTAssertEqual(Payload.decodeIfPresent(from: #"{"name":""}"#, options: options)?.name, "")
    }

    func testOptionalValueMappingAndSafeIntegerConversion() {
        struct Payload: ZHHJSONCodable {
            var createdAt: Date? = Date(timeIntervalSince1970: 0)
            var count: Int = 7
            var small: Int8 = 8

            static func valueMapping() -> [ZHHJSONValueMap] {
                [ZHHJSONValueMap(CodingKeys.createdAt, ZHHJSONDateTransform(.millisecondsSince1970))]
            }
        }

        let date = Payload.decodeIfPresent(from: #"{"createdAt":1700000000000}"#)
        XCTAssertEqual(date?.createdAt?.timeIntervalSince1970, 1_700_000_000)
        for value in ["nan", "inf", "1e999"] {
            XCTAssertEqual(Payload.decodeIfPresent(from: "{\"count\":\"\(value)\"}")?.count, 7)
        }
        XCTAssertEqual(Payload.decodeIfPresent(from: #"{"small":300}"#)?.small, 8)
    }

    func testDateCollectionsAndFlexiblePrimitiveCollections() throws {
        struct Payload: ZHHJSONCodable {
            var tags = ["default"]
            var url: URL? = URL(string: "https://default.example")
            var data: Data? = Data("default".utf8)
            var amount: Decimal? = 2
            var width: CGFloat? = 3
        }

        let dates = [Date(timeIntervalSince1970: 1_700_000_000)]
        let encoded = try FlexibleJSONEncoder().encode(dates)
        let decoded = try FlexibleJSONDecoder().decode([Date].self, from: encoded)
        XCTAssertEqual(decoded.first?.timeIntervalSince1970, dates.first?.timeIntervalSince1970)

        let payload = Payload.decodeIfPresent(
            from: #"{"tags":"bad","url":"https://example.com","data":"aGk=","amount":"12.5","width":"9"}"#
        )
        XCTAssertEqual(payload?.tags, ["default"])
        XCTAssertEqual(payload?.url?.host, "example.com")
        XCTAssertEqual(payload?.data, Data("hi".utf8))
        XCTAssertEqual(payload?.amount, Decimal(string: "12.5"))
        XCTAssertEqual(payload?.width, 9)
    }

    func testDictionaryDecodeAndUpdaterAliases() throws {
        let users = [String: User].decodeIfPresent(from: #"{"a":{"id":1},"bad":"x","b":{"id":"2"}}"#)
        XCTAssertEqual(users?.count, 2)
        XCTAssertEqual(users?["b"]?.id, 2)

        var user = try User.decode(from: #"{"user_id":1,"name":"old"}"#)
        try ZHHJSONUpdater.update(&user, from: #"{"userId":2,"name":"new"}"#)
        XCTAssertEqual(user.id, 2)
        XCTAssertEqual(user.name, "new")
    }

    func testThrowingEncodeAndIfPresentEncodeAPIs() throws {
        let user = User()
        XCTAssertFalse(try user.encodeData().isEmpty)
        XCTAssertNotNil(user.encodeDataIfPresent())
        XCTAssertNotNil([user].encodeObjectIfPresent())

        struct Failing: ZHHJSONCodable {
            enum CodingKeys: String, CodingKey { case value }
            var value = Double.nan

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(value, forKey: .value)
            }
        }

        XCTAssertThrowsError(try Failing().encodeData())
        XCTAssertNil(Failing().encodeDataIfPresent())

        let map = ["a": user]
        XCTAssertNotNil(try? map.encodeJSONString())
        XCTAssertNotNil(map.encodeObjectIfPresent())
    }

    func testOptionalNilDefaultStaysNil() {
        struct Payload: ZHHJSONCodable {
            var name: String? = nil
            var count: Int? = nil
            var user: User? = nil
        }

        let payload = Payload.decodeIfPresent(from: #"{}"#)
        XCTAssertNil(payload?.name)
        XCTAssertNil(payload?.count)
        XCTAssertNil(payload?.user)
        XCTAssertNil(Payload.decodeIfPresent(from: #"{"name":null,"count":null,"user":null}"#)?.name)
    }

    func testSingleValueJSON() throws {
        let decoder = FlexibleJSONDecoder()
        XCTAssertEqual(try decoder.decode(Int.self, from: "18"), 18)
        XCTAssertEqual(try decoder.decode(String.self, from: "\"hi\""), "hi")
        XCTAssertEqual(try decoder.decode(Bool.self, from: "true"), true)
        XCTAssertEqual(try decoder.decode(Double.self, from: "1.5"), 1.5)

        struct Box: ZHHJSONCodable {
            var value: Int = 7
        }
        XCTAssertEqual(Box.decodeIfPresent(from: "18")?.value, 7)
    }

    func testClassInheritanceDecodesParentFields() {
        class Account: ZHHJSONCodable {
            var age: Int = 2
            required init() {}
        }
        class VIPAccount: Account {
            enum CodingKeys: String, CodingKey { case level }
            var level: Int = 3
            required init() { super.init() }
            required init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                level = try container.decode(Int.self, forKey: .level)
                try super.init(from: decoder)
            }
        }

        let vip = VIPAccount.decodeIfPresent(from: #"{"age":9,"level":5}"#)
        XCTAssertEqual(vip?.age, 9)
        XCTAssertEqual(vip?.level, 5)
    }

    func testUpdaterNestedAliasesAndDateOptions() throws {
        struct Address: ZHHJSONCodable {
            var city = ""

            static func keyMapping() -> [ZHHJSONKeyMap] {
                [ZHHJSONKeyMap(CodingKeys.city, "city_name", "cityName", "city")]
            }
        }
        struct Person: ZHHJSONCodable {
            var name = ""
            var address = Address()
            var extra: Address? = Address()
        }

        var person = try Person.decode(from: #"{"name":"A","address":{"city_name":"北京"},"extra":{"city_name":"广州"}}"#)
        try ZHHJSONUpdater.update(&person, from: #"{"address":{"cityName":"上海"},"extra":{"city":"深圳"}}"#)
        XCTAssertEqual(person.name, "A")
        XCTAssertEqual(person.address.city, "上海")
        XCTAssertEqual(person.extra?.city, "深圳")

        struct Payload: ZHHJSONCodable {
            var createdAt = Date(timeIntervalSince1970: 0)
        }
        var payload = Payload()
        try ZHHJSONUpdater.update(
            &payload,
            from: #"{"createdAt":1700000000000}"#,
            decodeOptions: ZHHJSONDecodeOptions(dateStrategy: .millisecondsSince1970)
        )
        XCTAssertEqual(payload.createdAt.timeIntervalSince1970, 1_700_000_000)
    }

    func testUnkeyedDirtyValueFallsBackOnParent() throws {
        struct Point: Codable {
            var x = 1
            var y = 2

            init(x: Int = 1, y: Int = 2) {
                self.x = x
                self.y = y
            }

            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                x = try container.decode(Int.self)
                y = try container.decode(Int.self)
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode(x)
                try container.encode(y)
            }
        }
        struct Box: ZHHJSONCodable {
            var point = Point()
        }

        let ok = Box.decodeIfPresent(from: #"{"point":[3,4]}"#)
        XCTAssertEqual(ok?.point.x, 3)
        XCTAssertEqual(ok?.point.y, 4)
        let fallback = Box.decodeIfPresent(from: #"{"point":[3,"bad"]}"#)
        XCTAssertEqual(fallback?.point.x, 1)
        XCTAssertEqual(fallback?.point.y, 2)

        XCTAssertThrowsError(try FlexibleJSONDecoder().decode(Int.self, from: "\"bad\""))
        XCTAssertEqual(try FlexibleJSONDecoder().decode([Int].self, from: #"[1,"bad",3]"#), [1, 3])
    }

    func testNativeJSONDecoderCoversMoreTypes() throws {
        struct Sample: Decodable {
            let count: Int8?
            let amount: Decimal?
            let site: URL?
            let createdAt: Date?

            enum CodingKeys: String, CodingKey { case count, amount, site, createdAt }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                count = container.decodeFlexibleIfPresent(Int8.self, forKey: .count)
                amount = container.decodeFlexibleIfPresent(Decimal.self, forKey: .amount)
                site = container.decodeFlexibleIfPresent(URL.self, forKey: .site)
                createdAt = container.decodeFlexibleIfPresent(Date.self, forKey: .createdAt, strategy: .secondsSince1970)
            }
        }

        let sample = try JSONDecoder().decode(
            Sample.self,
            from: Data(#"{"count":"9","amount":"12.5","site":"https://example.com","createdAt":1700000000}"#.utf8)
        )
        XCTAssertEqual(sample.count, 9)
        XCTAssertEqual(sample.amount, Decimal(string: "12.5"))
        XCTAssertEqual(sample.site?.host, "example.com")
        XCTAssertEqual(sample.createdAt?.timeIntervalSince1970, 1_700_000_000)
        XCTAssertEqual(
            try JSONDecoder().decode(Sample.self, from: Data(#"{"count":300}"#.utf8)).count,
            nil
        )
    }
}
