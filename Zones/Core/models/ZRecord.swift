//
//  ZRecord.swift
//  Zones
//
//  Created by Jonathan Sand on 9/19/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


class ZRecord: NSObject {
    

    var storageMode: ZStorageMode?
    var  kvoContext: UInt8 = 1
    var     _record: CKRecord?
    var      isRoot: Bool { return record != nil && record.recordID.recordName == rootNameKey }


    var record: CKRecord! {
        get {
            return _record
        }

        set {
            if _record != newValue {
                _record = newValue

                register()
                updateClassProperties()
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

        gCloudManager.clearRecord(self)

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


    func updateClassProperties() {
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

        copy.needCreate() // so KVO won't call set needsMerge state bit
        updateCloudProperties()

        for keyPath: String in cloudProperties() {
            copy.record[keyPath] = record[keyPath]
        }

        copy.updateClassProperties()

        return copy
    }


    func mergeIntoAndTake(_ iRecord: CKRecord) {
        if record != nil {
            for keyPath: String in cloudProperties() {
                iRecord[keyPath] = record[keyPath]
            }
        }

        needSave()
        updateCloudProperties()
        unmarkForStates([.needsMerge])

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
            record = CKRecord(recordType: type!, recordID: CKRecordID(recordName: name!))

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
        return gCloudManager.hasRecord(self, forStates:states)
    }


    func markForStates(_ states: [ZRecordState]) {
        gCloudManager.addRecord(self, for: states)
    }


    func unmarkForStates(_ states: [ZRecordState]) {
        if let identifier = self.record?.recordID, let mode = storageMode {
            gCloudManager.removeRecordByRecordID(identifier, forStates:states, in: mode)
        }
    }


    func needSave()   { markForStates([.needsSave]) }
    func needFetch()  { markForStates([.needsFetch]) }
    func needCreate() { markForStates([.needsCreate]) }
    func needParent() { markForStates([.needsParent]) }


    func maybeNeedMerge() {
        if !isMarkedForStates([.needsCreate]) {
            markForStates([.needsMerge])
        }
    }


    func needChildren() {
        if !isMarkedForStates([.needsChildren, .hasChildren]) {
            markForStates    ([.needsChildren, .hasChildren])

            if let zone = self as? Zone {
                toConsole("need children for \(zone.zoneName ?? "NO NAME")")

            }
        }
    }


    // MARK:- accessors and KVO
    // MARK:-


    func setValue(_ value: NSObject, forPropertyName: String) {
        gCloudManager.setIntoObject(self, value: value, forPropertyName: forPropertyName)
    }


    func get(propertyName: String) {
        gCloudManager.getFromObject(self, valueForPropertyName: propertyName)
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
