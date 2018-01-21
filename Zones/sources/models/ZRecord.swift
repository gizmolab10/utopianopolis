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
    

    var           _record: CKRecord?
    var       storageMode: ZStorageMode?
    var        kvoContext: UInt8 = 1
    var isRootOfFavorites: Bool             { return record != nil && recordName == kFavoritesRootName }
    var        isBookmark: Bool             { return record.isBookmark }
    var            isRoot: Bool             { return record != nil && kRootNames.contains(recordName!) }
    var           canSave: Bool             { return !hasState(.requiresFetch) }
    var         needsSave: Bool             { return hasState(.needsSave) }
    var         needsRoot: Bool             { return hasState(.needsRoot) }
    var        needsCount: Bool             { return hasState(.needsCount) }
    var        needsColor: Bool             { return hasState(.needsColor) }
    var        needsFetch: Bool             { return hasState(.needsFetch) }
    var        needsMerge: Bool             { return hasState(.needsMerge) }
    var       needsTraits: Bool             { return hasState(.needsTraits) }
    var       needsParent: Bool             { return hasState(.needsParent) }
    var      needsDestroy: Bool             { return hasState(.needsDestroy) }
    var      needsProgeny: Bool             { return hasState(.needsProgeny) }
    var     needsWritable: Bool             { return hasState(.needsWritable) }
    var     needsChildren: Bool             { return hasState(.needsChildren) }
    var    needsBookmarks: Bool             { return hasState(.needsBookmarks) }
    var    recordsManager: ZRecordsManager? { return gRemoteStoresManager.recordsManagerFor(storageMode) }
    var      cloudManager: ZCloudManager?   { return recordsManager as? ZCloudManager }
    var        recordName: String?          { return record?.recordID.recordName }


    var record: CKRecord! {
        get {
            return _record
        }

        set {
            if  _record != newValue {
                gBookmarksManager.unregisterBookmark(self as? Zone)
                cloudManager?.unregisterCKRecord(_record)

                _record  = newValue

                register()
                updateInstanceProperties()
                setupLinks()

                let zone = self as? Zone
                let name = zone?.zoneName

//                if  zone?.badJonathan() ?? false {
//                    zone?.orphan()
//                }

                if       !canSave &&  alreadyExists {
                    columnarReport("ALLOW SAVE", name ?? recordName)
                    allowSave()
                } else if canSave && !alreadyExists {
//                    columnarReport("DON'T SAVE", name ?? recordName)
                    requireFetch()

                    if name != nil || recordName == kRootName {
                        bam("named ... should allow saving")
                    }
                }
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
            return gRemoteStoresManager.cloudManagerFor(mode).maybeZoneForRecordID(record.recordID)
        }

        return nil
    }


    var manifest: ZManifest? {
        if let mode = storageMode {
            return gRemoteStoresManager.manifest(for: mode)
        }

        return nil
    }


    var showChildren: Bool  {
        var show = false

        if isRootOfFavorites {
            show = true
        } else if let m = manifest {
            show    = m.isExpanded(self.recordName)
        }

        return show
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

        unorphan()
    }


    deinit {
        teardownKVO()
    }


    func unorphan() {}
    func debug(_  iMessage: String) {}
    func cloudProperties() -> [String] { return [] }
    func   register() { cloudManager?  .registerZRecord(self) }
    func unregister() { cloudManager?.unregisterZRecord(self) }
    func hasMissingChildren() -> Bool { return false }
    func hasMissingProgeny()  -> Bool { return false }


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


    func useBest(record iRecord: CKRecord) {
        let      myDate = record?.modificationDate
        if  let newDate = iRecord.modificationDate,
            (myDate    == nil || myDate!.timeIntervalSince(newDate) < 0) {
            record      = iRecord
        }
    }


    func copy(into copy: ZRecord) {
        copy.maybeNeedSave() // so KVO won't set needsMerge
        updateRecordProperties()
        record.copy(to: copy.record, properties: cloudProperties())
        copy.updateInstanceProperties()
    }


    func mergeIntoAndTake(_ iRecord: CKRecord) {
        updateRecordProperties()

        if  record != nil && record.copy(to: iRecord, properties: cloudProperties()) {
            record  = iRecord

            maybeNeedSave()
        }
    }


    func setStorageDictionary(_ dict: ZStorageDict) {
        storageMode       = gStorageMode
        var type: String? = nil
        var name: String? = nil

        for (key, value) in dict {
            switch key {
            case kRecordType: type = value as? String; break
            case kRecordName: name = value as? String; break
            default:                                     break
            }
        }

        if type != nil && name != nil {
            record = CKRecord(recordType: type!, recordID: CKRecordID(recordName: name!)) // YIKES this may be wildly out of date

            self.updateRecordProperties()

            // any subsequent changes into any of this object's cloudProperties will fetch / save this record from / to iCloud
        }
    }


    func storageDictionary() -> ZStorageDict? {
        return record == nil ? [:] :
            [kRecordName : recordName!       as NSObject,
             kRecordType : record.recordType as NSObject]
    }


    // MARK:- states
    // MARK:-


    func hasState(_ state: ZRecordState) -> Bool { return recordsManager?.hasZRecord(self, forAnyOf:[state]) ?? false }
    func addState(_ state: ZRecordState)         {        recordsManager?.addZRecord(self,     for: [state]) }
    func clearAllStates()                        {        recordsManager?.clearAllStatesForCKRecord(self.record) }


    func removeState(_ state: ZRecordState) {
        if let identifier = self.record?.recordID {
            recordsManager?.clearRecordID(identifier, for:[state])
        }
    }


    func needRoot()     { addState(.needsRoot) }
    func needCount()    { addState(.needsCount) }
    func needColor()    { addState(.needsColor) }
    func needTraits()   { addState(.needsTraits) }
    func needParent()   { addState(.needsParent) }
    func needWritable() { addState(.needsWritable) }
    func requireFetch() { addState(.requiresFetch) }
    func allowSave()    { removeState(.requiresFetch)}


    func needProgeny() {
        if  !kFullFetch || hasMissingProgeny() {
            addState(.needsProgeny)
            removeState(.needsChildren)
        }
    }


    func needDestroy() {
        if  canSave {
            addState   (.needsDestroy)
            removeState(.needsSave)
            removeState(.needsMerge)
        }
    }


    func needChildren() {
        if   !isBookmark && // no bookmark has children, by design
            (!kFullFetch || (showChildren && hasMissingChildren() && !needsProgeny)) {
            addState(.needsChildren)
        }
    }


    func maybeNeedSave() {
        if !needsDestroy, !needsFetch, canSave {
            removeState(.needsMerge)
            addState   (.needsSave)
        }
    }


    func maybeNeedMerge() {
        if  alreadyExists, canSave, !needsSave, !needsMerge, !needsDestroy {
            addState(.needsMerge)
        }
    }

    
    func maybeNeedFetch() {
        if !alreadyExists {
            addState(.needsFetch)
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
