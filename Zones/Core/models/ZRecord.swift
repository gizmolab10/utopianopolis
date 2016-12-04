//
//  ZRecord.swift
//  Zones
//
//  Created by Jonathan Sand on 9/19/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


struct ZRecordState: OptionSet {
    let rawValue: Int

    static let ready         = ZRecordState(rawValue:      0)
    static let needsSave     = ZRecordState(rawValue: 1 << 0)
    static let needsFetch    = ZRecordState(rawValue: 1 << 1)
    static let needsMerge    = ZRecordState(rawValue: 1 << 2)
    static let needsCreate   = ZRecordState(rawValue: 1 << 3)
    static let needsDelete   = ZRecordState(rawValue: 1 << 4)
    static let needsChildren = ZRecordState(rawValue: 1 << 5)
}


class ZRecord: NSObject {
    

    var storageMode: ZStorageMode?
    var recordState: ZRecordState = .ready
    var  kvoContext: UInt8        = 1
    var     _record: CKRecord?


    var record: CKRecord! {
        get {
            return _record
        }

        set {
            if _record != newValue {
                _record = newValue

                if _record == nil {
                    recordState.insert(.needsCreate)
                } else {
                    register()
                }

                updateZoneProperties()
            }
        }
    }


    var storageDict: ZStorageDict {
        get {
            return storageDictionary()!
        }

        set {
            if newValue.count > 0 {
                setStorageDictionary(newValue)
            }
        }
    }


    override init() {
        super.init()

        self.recordState = ZRecordState.ready
        self.storageMode = nil
        self.record      = nil

        self.setupKVO();
    }


    convenience init(record: CKRecord?, storageMode: ZStorageMode?) {
        self.init()

        self.storageMode = storageMode
        self.record      = record
    }


    deinit {
        teardownKVO()
    }


    // MARK:- overrides
    // MARK:-


    func register() {}
    func cloudProperties() -> [String] { return [] }


    // MARK:- properties
    // MARK:-


    func containsStateIn(_ states: [ZRecordState], onEach: ObjectClosure) {
        var matches = false

        for state in states {
            if recordState.contains(state) {
                matches = true
            }
        }

        if matches {
            onEach(self)
        }
    }


    func updateZoneProperties() {
        if record != nil {
            for keyPath in cloudProperties() {
                if let cloudValue = record[keyPath] as! NSObject? {
                    let propertyValue = value(forKeyPath: keyPath) as! NSObject?

                    if propertyValue != cloudValue {
                        setValue(cloudValue, forKeyPath: keyPath)
                    }
                }
            }
        }
    }


    func updateCloudProperties() {
        if record != nil {
            for keyPath in cloudProperties() {
                let    cloudValue = record[keyPath] as! NSObject?
                let propertyValue = value(forKeyPath: keyPath) as! NSObject?

                if propertyValue != nil && propertyValue != cloudValue {
                    record[keyPath] = propertyValue as? CKRecordValue
                }
            }
        }
    }


    func mergeIntoAndTake(_ iRecord: CKRecord) {
        if record != nil {
            for keyPath: String in cloudProperties() {
                iRecord[keyPath] = record[keyPath]
            }
        }

        recordState.remove(.needsMerge)
        needSave()

        record = iRecord
    }


    func setStorageDictionary(_ dict: ZStorageDict) {
        storageMode       = travelManager.storageMode
        var type: String? = nil
        var name: String? = nil

        for (key, value) in dict {
            switch key {
            case recordTypeKey: type = value as? String; break
            case recordNameKey: name = value as? String; break
            default:                                     break
            }
        }

        if type != nil && name != nil {
            record      = CKRecord(recordType: type!, recordID: CKRecordID(recordName: name!))

            recordState.remove(.needsCreate)
            self.updateCloudProperties()

            // any subsequent changes into any of this object's cloudProperties will fetch / save this record from / to iCloud
        }
    }


    func storageDictionary() -> ZStorageDict? {
        return record == nil ? [:] :
            [recordNameKey : record.recordID.recordName as NSObject,
             recordTypeKey : record.recordType          as NSObject]
    }


    // MARK:- accessors and KVO
    // MARK:-


    func needSave() {
        recordState.insert(.needsSave)
    }


    func needFetch() {
        recordState.insert(.needsFetch)
    }


    func needChildren() {
        recordState.insert(.needsChildren)
    }


    func setValue(_ value: NSObject, forPropertyName: String) {
        cloudManager.setIntoObject(self, value: value, forPropertyName: forPropertyName)
    }


    func get(propertyName: String) {
        cloudManager.getFromObject(self, valueForPropertyName: propertyName)
    }


    func teardownKVO() {
        for keyPath: String in cloudProperties() {
            removeObserver(self, forKeyPath: keyPath)
        }
    }


    func setupKVO() {
        for keyPath: String in cloudProperties() {
            addObserver(self, forKeyPath: keyPath, options: [.new, .old], context: &kvoContext)
        }
    }


    override func observeValue(forKeyPath keyPath: String?, of iObject: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &kvoContext {
            let observer = iObject as! NSObject

            if let value: NSObject = observer.value(forKey: keyPath!) as! NSObject? {
                setValue(value, forPropertyName: keyPath!)
            }
        }
    }
}
