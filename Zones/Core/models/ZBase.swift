//
//  ZBase.swift
//  Zones
//
//  Created by Jonathan Sand on 9/19/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZBase {
    

    var        record: CKRecord!
    weak var database: CKDatabase!


    init(record: CKRecord, database: CKDatabase) {
        self.database = database
        self.record   = record
    }


    func set(propertyName:String, withValue: AnyObject) {
        modelManager.set(intoObject: self, itsPropertyName: propertyName, withValue: withValue)
    }


    func get(propertyName: String) {
        modelManager.get(fromObject: self, valueForPropertyName: propertyName)
    }


}
