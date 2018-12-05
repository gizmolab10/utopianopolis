//
//  ZPostgres.swift
//  iFocus
//
//  Created by Jonathan Sand on 7/13/18.
//  Copyright © 2018 Jonathan Sand. All rights reserved.
//

import Foundation
import libPG

let gPostgresql = ZPostgresql()

class ZPostgresql: NSObject {
    var config: Client.Config
    let pool: Pool

    override init() {
        self.config = Client.Config(host: "zones.cwbqytqwjs5w.us-west-1.rds.amazonaws.com", user: "jonathansand", password: "B00blebabble", database: "thoughtful")
        self.pool = Pool(config)
    }

    func foo() {
        let query = Query("SELECT version()")

        pool.exec(query) { result in
            switch result {
            case .success(let result):
                print("name: \(result.rows.first?["name"] ?? "")")
            case .failure(let error):
                print("failed to excecute query: \(error)")
            }
        }
    }
}
