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
    

    var        _record: CKRecord?
    var    storageMode: ZStorageMode?
    var     kvoContext: UInt8 = 1
    var    isLocalOnly: Bool  = false
    var         isRoot: Bool             { return record != nil && gRootNames.contains(recordName!) }
    var      needsSave: Bool             { return hasState(.needsSave) }
    var      needsRoot: Bool             { return hasState(.needsRoot) }
    var     needsCount: Bool             { return hasState(.needsCount) }
    var     needsColor: Bool             { return hasState(.needsColor) }
    var     needsFetch: Bool             { return hasState(.needsFetch) }
    var     needsMerge: Bool             { return hasState(.needsMerge) }
    var    needsTraits: Bool             { return hasState(.needsTraits) }
    var    needsParent: Bool             { return hasState(.needsParent) }
    var   needsDestroy: Bool             { return hasState(.needsDestroy) }
    var   needsProgeny: Bool             { return hasState(.needsProgeny) }
    var  needsWritable: Bool             { return hasState(.needsWritable) }
    var  needsChildren: Bool             { return hasState(.needsChildren) }
    var needsBookmarks: Bool             { return hasState(.needsBookmarks) }
    var recordsManager: ZRecordsManager? { return gRemoteStoresManager.recordsManagerFor(storageMode) }
    var   cloudManager: ZCloudManager?   { return recordsManager as? ZCloudManager }
    var     recordName: String?          { return record?.recordID.recordName }


    var record: CKRecord! {
        get {
            return _record
        }

        set {
            if  _record != newValue {
                _record  = newValue

                register()
                updateInstanceProperties()
                setupLinks()
            }
        }
    }


    var alreadyExists: Bool {
        if  let    r = record {
            return r.creationDate != nil
        }

        return false
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


    var target: ZRecord? {
        if  let mode = storageMode {
            return gRemoteStoresManager.cloudManagerFor(mode).zoneForRecordID(record.recordID)
        }

        return nil
    }


    // MARK:- overrides
    // MARK:-


    override init() {
        super.init()

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


    func unorphan() {}
    func debug(_  iMessage: String) {}
    func cloudProperties() -> [String] { return [] }
    func   register() { cloudManager?  .registerZRecord(self) }
    func unregister() { cloudManager?.unregisterZRecord(self) }


    // MARK:- properties
    // MARK:-


    func setupLinks() {}


    func updateInstanceProperties() {
        if record != nil {
            for keyPath in cloudProperties() {
                if  let    cloudValue = record[keyPath] as! NSObject? {
                    let propertyValue = value(forKeyPath: keyPath) as! NSObject?

                    if propertyValue != cloudValue {
                        setValue(cloudValue, forKeyPath: keyPath)
                    }
                }
            }
        }
    }


    func updateRecordProperties() {
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


    func copy(into copy: ZRecord) {
        copy.needSave() // so KVO won't set needsMerge
        updateRecordProperties()

        for keyPath: String in cloudProperties() {
            copy.record[keyPath] = record[keyPath]
        }

        copy.updateInstanceProperties()
    }


    func mergeIntoAndTake(_ iRecord: CKRecord) {
        updateRecordProperties()

        if record != nil {
            for keyPath: String in cloudProperties() {
                iRecord[keyPath] = record[keyPath]
            }
        }

        record = iRecord

        needSave()
    }


    func setStorageDictionary(_ dict: ZStorageDict) {
        storageMode       = gStorageMode
        var type: String? = nil
        var name: String? = nil

        for (key, value) in dict {
            switch key {
            case gRecordTypeKey: type = value as? String; break
            case gRecordNameKey: name = value as? String; break
            default:                                     break
            }
        }

        if type != nil && name != nil {
            record = CKRecord(recordType: type!, recordID: CKRecordID(recordName: name!))

            self.updateRecordProperties()

            // any subsequent changes into any of this object's cloudProperties will fetch / save this record from / to iCloud
        }
    }


    func storageDictionary() -> ZStorageDict? {
        return record == nil ? [:] :
            [gRecordNameKey : recordName!       as NSObject,
             gRecordTypeKey : record.recordType as NSObject]
    }


    // MARK:- states
    // MARK:-


    func hasState(_ state: ZRecordState) -> Bool { return recordsManager?.hasZRecord(self, forAnyOf:[state]) ?? false }
    func addState(_ state: ZRecordState)         {        recordsManager?.addZRecord(self,     for: [state]) }
    func clearAllStates()                        {        recordsManager?.clearAllStatesForRecord(self.record) }


    func removeState(_ state: ZRecordState) {
        if let identifier = self.record?.recordID {
            recordsManager?.clearStatesForRecordID(identifier, forStates:[state])
        }
    }


    func needRoot()      { addState(.needsRoot) }
    func needCount()     { addState(.needsCount) }
    func needColor()     { addState(.needsColor) }
    func needTraits()    { addState(.needsTraits) }
    func needParent()    { addState(.needsParent) }
    func needProgeny()   { addState(.needsProgeny); removeState(.needsChildren) }
    func needDestroy()   { addState(.needsDestroy); removeState(.needsSave); removeState(.needsMerge) }
    func needWritable()  { addState(.needsWritable) }
    func needChildren()  { addState(.needsChildren) }
    func needBookmarks() { addState(.needsBookmarks) }


    func needSave() {
        removeState(.needsMerge)

        if !isLocalOnly, !needsDestroy, storageMode != .favoritesMode, recordName != gFavoriteRootNameKey {
            addState(.needsSave)
        }
    }


    func maybeNeedFetch() {
        if !alreadyExists {
            addState(.needsFetch)
        }
    }


    func maybeNeedMerge() {
        if !isLocalOnly, !needsSave, !needsMerge, !needsDestroy {
            addState(.needsMerge)
        }
    }


    // MARK:- accessors and KVO
    // MARK:-


    func setValue(_ value: NSObject, for property: String) {
        cloudManager?.setIntoObject(self, value: value, for: property)
    }


    func get(propertyName: String) {
        cloudManager?.getFromObject(self, valueForPropertyName: propertyName)
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
                setValue(value, for: keyPath!)
            }
        }
    }
}
