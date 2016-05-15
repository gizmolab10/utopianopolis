//
//  UNeed.swift
//  Utopia
//
//  Created by Jonathan Sand on 5/14/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import RealmSwift
import os


class UNeed: Object {
    dynamic var requestor: UUtopian

    init(requestor: UUtopian) {
        self.requestor = requestor
    }

//    required init(realm: RLMRealm, schema: RLMObjectSchema) {
//        fatalError("init(realm:schema:) has not been implemented")
//    }
}
