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
    
    
    func set(propertyName:NSString, withValue:NSObject) {
        modelManager.set(object: self, propertyName: propertyName, withValue: withValue)
    }


    func get(propertyName:NSString) -> NSObject? {
        return modelManager.get(object: self, propertyName: propertyName)
    }


}
