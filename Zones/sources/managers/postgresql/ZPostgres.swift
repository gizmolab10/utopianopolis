//
//  ZPostgres.swift
//  iFocus
//
//  Created by Jonathan Sand on 7/13/18.
//  Copyright © 2018 Zones. All rights reserved.
//

import Foundation
import PG

class ZPostgress: NSObject {
    let parameters = ConnectionParameters(
        host: "zones.cwbqytqwjs5w.us-west-1.rds.amazonaws.com",
        port: "5432",
        databaseName: "thoughtful",
        login: "jonathansand",
        password: "B00blebabble"
    )
//    var connection {
//        return try Database.connect(parameters: parameters)
//    }
}
