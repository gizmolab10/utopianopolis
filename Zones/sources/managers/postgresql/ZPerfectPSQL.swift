//
//  ZPerfectPSQL.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 7/20/18.
//  Copyright © 2018 Jonathan Sand. All rights reserved.
//

import Foundation
import PerfectPostgreSQL

class ZPerfectPSQL: NSObject {

    class func foo() {
        let p = PGConnection()
        let status = p.connectdb("host=zones.cwbqytqwjs5w.us-west-1.rds.amazonaws.com dbname=thoughtful")

        let result = p.exec(
            statement: "select version()")
    }
}
