//
//  ZRecord.swift
//  Zones
//
//  Created by Jonathan Sand on 9/19/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZRecord: NSObject {
    

    var storageMode: ZStorageMode?
    var  kvoContext: UInt8 = 1
    var     _record: CKRecord?
    var      isRoot: Bool { get { return record != nil && record.recordID.recordName == rootNameKey } }


    var record: CKRecord! {
        get {
            return _record
        }

        set {
            if _record != newValue {
                _record = newValue

                register()
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


    // MARK:- overrides
    // MARK:-


    override init() {
        super.init()

        cloudManager.clearRecord(self)

        self.storageMode = nil
        self.record      = nil

        self.setupKVO();
    }


    convenience init(record: CKRecord?, storageMode: ZStorageMode?) {
        self.init()

        self.storageMode = storageMode

        if record != nil {
            self.record = record
        }
    }


    deinit {
        teardownKVO()
    }


    func register() {}
    func debug(_  iMessage: String) {}
    func cloudProperties() -> [String] { return [] }


    // MARK:- properties
    // MARK:-


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


    func deepCopy() -> Zone {
        let copy = Zone(record: CKRecord(recordType: zoneTypeKey), storageMode: gStorageMode)

        updateCloudProperties()

        for keyPath: String in cloudProperties() {
            copy.record[keyPath] = record[keyPath]
        }

        copy.updateZoneProperties()

        return copy
    }


    func mergeIntoAndTake(_ iRecord: CKRecord) {
        if record != nil {
            for keyPath: String in cloudProperties() {
                iRecord[keyPath] = record[keyPath]
            }
        }

        // self.unmarkForStates([.needsMerge])
        needUpdateSave()

        record = iRecord
    }


    func setStorageDictionary(_ dict: ZStorageDict) {
        storageMode       = gStorageMode
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

            self.updateCloudProperties()

            // any subsequent changes into any of this object's cloudProperties will fetch / save this record from / to iCloud
        }
    }


    func storageDictionary() -> ZStorageDict? {
        return record == nil ? [:] :
            [recordNameKey : record.recordID.recordName as NSObject,
             recordTypeKey : record.recordType          as NSObject]
    }


    // MARK:- states
    // MARK:-


    func isMarkedForStates(_ states: [ZRecordState]) -> Bool {
        return detectWithMode(storageMode!) {
            cloudManager.hasRecord(self, forStates:states)
        }
    }


    func markForStates(_ states: [ZRecordState]) {
        invokeWithMode(storageMode) {
            cloudManager.addRecord(self, forStates:states)
        }
    }
    

    func unmarkForStates(_ states: [ZRecordState]) {
        invokeWithMode(storageMode) {
            cloudManager.removeRecordByRecordID(self.record.recordID, forStates:states)
        }
    }


    func needUpdateSave() { markForStates([.needsSave]); updateCloudProperties() }
    func needJustSave()   { markForStates([.needsSave]) }
    func needFetch()      { markForStates([.needsFetch]) }
    func needCreate()     { markForStates([.needsCreate]) }
    func needParent()     { markForStates([.needsParent]) }
    func needChildren()   { markForStates([.needsChildren]) }


    // MARK:- accessors and KVO
    // MARK:-


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
