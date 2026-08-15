//
//  ViewController.swift
//  ZHHJSONCodable
//
//  Created by 桃色三岁 on 2026/8/13.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHJSONCodable

private struct DemoUser: ZHHJSONCodable {
    var id: Int64 = 0
    var name: String = ""
    var vip: Bool = false

    static func keyMapping() -> [ZHHJSONKeyMap] {
        [ZHHJSONKeyMap(CodingKeys.id, "user_id", "userId", "id")]
    }
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let json = #"{"user_id":"1001","name":2026,"vip":"true"}"#
        if let user = DemoUser.decodeIfPresent(from: json) {
            print("ZHHJSONCodable demo | id=\(user.id) name=\(user.name) vip=\(user.vip)")
        }
    }
}
