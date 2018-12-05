//
//  ZFluentPSQL.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 7/26/18.
//  Copyright © 2018 Jonathan Sand. All rights reserved.
//

import Foundation
import PostgreSQLDriver
import PostgreSQL
import Fluent


class ZFluentPSQL: NSObject {
    let postgresql = try PostgreSQL.Database(
        hostname: "127.0.0.1",
        port: 5432,
        database: "postgres",
        user: "postgres",
        password: ""
    )

    let driver = PostgreSQLDriver.Driver(master: postgresql)
}
