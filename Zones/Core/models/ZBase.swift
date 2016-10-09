//
//  ZBase.swift
//  Zones
//
//  Created by Jonathan Sand on 9/19/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZBase: NSObject {
    

    var               unsaved: Bool  = false
    var            kvoContext: UInt8 = 1
    weak dynamic var database: CKDatabase!
    var               _record: CKRecord?
    var                record: CKRecord! {
        get {
            return _record
        }

        set {
            _record = newValue

            updateProperties()
        }
    }
    var storageDict: [String : NSObject] {
        get {
            return storageDictionary()!
        }

        set {
            if newValue.count > 0 {
                setStorageDictionary(newValue)
            }
        }
    }

    init(record: CKRecord, database: CKDatabase) {
        super.init()

        self.database = database
        self.record   = record

        self.setupKVO();
        modelManager.registerObject(self)
    }


    // MARK:- overrides
    // MARK:-


    func updateProperties() {}


    func setStorageDictionary(_ dict: [String : NSObject]) {}


    func storageDictionary() -> [String : NSObject]? {
        return nil
    }


    func propertyKeyPaths() -> [String] {
        return []
    }


    // MARK:- accessors and KVO
    // MARK:-


    func set(propertyName:String, withValue: NSObject) {
        modelManager.set(intoObject: self, itsPropertyName: propertyName, withValue: withValue)
    }


    func get(propertyName: String) {
        modelManager.get(fromObject: self, valueForPropertyName: propertyName)
    }


    func setupKVO() {
        for keyPath: String in propertyKeyPaths() {
            self.addObserver(self, forKeyPath: keyPath, options: [.new, .old], context: &kvoContext)
        }
    }


    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &kvoContext {
            let observed = object as! NSObject
            let    value = observed.value(forKey: keyPath!) as! NSObject

            self.set(propertyName: keyPath!, withValue: value)
        }
    }
}
