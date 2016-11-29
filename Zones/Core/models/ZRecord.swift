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
    static let needsDelete   = ZRecordState(rawValue: 1 << 3)
    static let needsChildren = ZRecordState(rawValue: 1 << 4)
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

                if _record != nil {
                    cloudManager.registerObject(self)
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


    init(record: CKRecord?, storageMode: ZStorageMode?) {
        super.init()

        self.recordState = ZRecordState.ready
        self.storageMode = storageMode
        self.record      = record

        self.setupKVO();
    }


    deinit {
        teardownKVO()
    }


    // MARK:- overrides
    // MARK:-


    func saveToCloud() {}
    func updateZoneProperties() {}
    func updateCloudProperties() {}
    func cloudProperties() -> [String] { return [] }


    func mergeIntoAndTake(_ iRecord: CKRecord) {
        if record != nil {
            for keyPath: String in cloudProperties() {
                iRecord[keyPath] = record[keyPath]
            }
        }

        recordState.remove(.needsMerge)
        needsSave()

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
            recordState = .ready

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


    func needsSave() {
        recordState.insert(.needsSave)
    }


    func needsFetch() {
        recordState.insert(.needsFetch)
    }


    func needsChildren() {
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
