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


    var record: CKRecord! {
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


    init(record: CKRecord?, database: CKDatabase) {
        super.init()

        self.database = database
        self.record   = record

        self.setupKVO();
        modelManager.registerObject(self)
    }


    // MARK:- overrides
    // MARK:-


    func cloudProperties() -> [String] {
        return []
    }


    func updateProperties() {}


    func setStorageDictionary(_ dict: [String : NSObject]) {
        var type: String? = nil
        var name: String? = nil

        for (key, value) in dict {
            switch key {
            case "recordType": type = value as? String; break
            case "recordName": name = value as? String; break
            default:                                    break
            }
        }

        if type != nil && name != nil {
            record = CKRecord(recordType: type!, recordID: CKRecordID(recordName: name!))

            // any subsequent changes into any of this object's cloudProperties will fetch / save this record from / to iCloud
        }
    }


    func storageDictionary() -> [String : NSObject]? {
        return ["recordName" : record.recordID.recordName as NSObject,
                "recordType" : record.recordType          as NSObject]
    }


    // MARK:- accessors and KVO
    // MARK:-


    func set(propertyName:String, withValue: NSObject) {
        if record != nil {
            modelManager.set(intoObject: self, itsPropertyName: propertyName, withValue: withValue)
        }
    }


    func get(propertyName: String) {
        modelManager.get(fromObject: self, valueForPropertyName: propertyName)
    }


    func setupKVO() {
        for keyPath: String in cloudProperties() {
            self.addObserver(self, forKeyPath: keyPath, options: [.new, .old], context: &kvoContext)
        }
    }


    override func observeValue(forKeyPath keyPath: String?, of iObject: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &kvoContext {
            let observed = iObject as! NSObject
            let   object = observed.value(forKey: keyPath!)

            if object != nil {
                let value = object as! NSObject

                self.set(propertyName: keyPath!, withValue: value)
            }
        }
    }
}
