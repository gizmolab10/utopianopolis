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
    

    var             _record: CKRecord?
    var          databaseID: ZDatabaseID?
    var          kvoContext: UInt8 = 1
    var           hasParent: Bool             { return false }
    var        showChildren: Bool             { return isExpanded(self.recordName) }
    var   isRootOfFavorites: Bool             { return record != nil && recordName == kFavoritesRootName }
    var          isBookmark: Bool             { return record?.isBookmark ?? false }
    var              isRoot: Bool             { return record != nil && kRootNames.contains(recordName!) }
    var           isFetched: Bool             { return !hasState(.notFetched) }
    var           needsSave: Bool             { return  hasState(.needsSave) }
    var           needsRoot: Bool             { return  hasState(.needsRoot) }
    var          notFetched: Bool             { return  hasState(.notFetched) }
    var          needsCount: Bool             { return  hasState(.needsCount) }
    var          needsColor: Bool             { return  hasState(.needsColor) }
    var          needsFetch: Bool             { return  hasState(.needsFetch) }
    var          needsMerge: Bool             { return  hasState(.needsMerge) }
    var         needsTraits: Bool             { return  hasState(.needsTraits) }
    var         needsParent: Bool             { return  hasState(.needsParent) }
    var        needsDestroy: Bool             { return  hasState(.needsDestroy) }
    var        needsProgeny: Bool             { return  hasState(.needsProgeny) }
    var       needsWritable: Bool             { return  hasState(.needsWritable) }
    var       needsChildren: Bool             { return  hasState(.needsChildren) }
    var      needsBookmarks: Bool             { return  hasState(.needsBookmarks) }
    var canSaveWithoutFetch: Bool             { return !hasState(.requiresFetchBeforeSave) }
    var      recordsManager: ZRecordsManager? { return gRemoteStoresManager.recordsManagerFor(databaseID) }
    var        cloudManager: ZCloudManager?   { return recordsManager as? ZCloudManager }
    var          recordName: String?          { return record?.recordID.recordName }


    var record: CKRecord! {
        get {
            return _record
        }

        set {
            if  _record != newValue {

                ///////////////////////////////////////////
                // old registrations are no longer valid //
                ///////////////////////////////////////////

                clearAllStates() // is this needed pr wanted?
                gBookmarksManager.unregisterBookmark(self as? Zone)
                cloudManager?.unregisterCKRecord(_record)

                _record = newValue

                updateInstanceProperties()

                if !register() {
                    bam("zone is a duplicate")
                } else {
                    maybeMarkAsFetched()

                    if  notFetched {
                        setupLinks()
                    }

                    /////////////////////
                    // debugging tests //
                    /////////////////////

                    let zone = self as? Zone
                    let name = zone?.zoneName ?? recordName ?? kNoValue

                    if       !canSaveWithoutFetch &&  isFetched {
                        bam("new record, ALLOW SAVE WITHOUT FETCH " + name)
                        allowSaveWithoutFetch()
                    } else if canSaveWithoutFetch && notFetched {
                        bam("require FETCH BEFORE SAVE " + name)
                        fetchBeforeSave()

                        if  name != kNoValue || recordName == kRootName {
                            bam("new named record, should ALLOW SAVING")
                        }
                    }
                }
            }
        }
    }


    func isExpanded(_ iRecordName: String?) -> Bool {
        if  let                      name   = iRecordName,
            gExpandedZones.index(of: name) != nil {
            return true
        }

        return false
    }


    func revealChildren() {
        var expansionSet = gExpandedZones

        if  let name = recordName, !isBookmark, !expansionSet.contains(name) {
            expansionSet.append(name)

            gExpandedZones = expansionSet
        }
    }


    func concealChildren() {
        var expansionSet = gExpandedZones

        if let  name = recordName {
            while let index = expansionSet.index(of: name) {
                expansionSet.remove(at: index)
            }
        }

        if  gExpandedZones.count != expansionSet.count {
            gExpandedZones        = expansionSet
        }
    }


    func toggleChildrenVisibility() {
        if  showChildren {
            concealChildren()
        } else {
            revealChildren()
        }
    }


    // MARK:- overrides
    // MARK:-


    override init() {
        super.init()

        self.databaseID = nil
        self.record      = nil

        self.setupKVO();
    }


    convenience init(record: CKRecord?, databaseID: ZDatabaseID?) {
        self.init()

        self.databaseID = databaseID

        if  let r = record {
            self.record = r
        }

        unorphan()
    }


    deinit {
        teardownKVO()
    }


    func orphan() {}
    func unorphan() {}
    func maybeNeedRoot() {}
    func debug(_  iMessage: String) {}
    func cloudProperties() -> [String] { return [] }
    func   register() -> Bool { return cloudManager?.registerZRecord(self) ?? false }
    func unregister() { cloudManager?.unregisterZRecord(self) }
    func hasMissingChildren() -> Bool { return true }
    func hasMissingProgeny()  -> Bool { return true }


    // MARK:- properties
    // MARK:-


    func setupLinks() {}


    func temporarilyMarkNeeds(_ closure: Closure) {
        cloudManager?.temporarilyForRecordNamed(recordName, ignoreNeeds: false, closure)
    }


    func temporarilyIgnoreNeeds(_ closure: Closure) {
        cloudManager?.temporarilyForRecordNamed(recordName, ignoreNeeds: true, closure)
    }


    func updateInstanceProperties() {
        if record != nil {
            for keyPath in cloudProperties() {
                if  let    cloudValue  = record[keyPath] as! NSObject? {
                    let propertyValue  = value(forKeyPath: keyPath) as! NSObject?

                    if  propertyValue != cloudValue {
                        setValue(cloudValue, forKeyPath: keyPath)
                    }
                }
            }
        }
    }


    func updateRecordProperties() {
        if record != nil {
            for keyPath in cloudProperties() {
                let    cloudValue  = record[keyPath] as! NSObject?
                let propertyValue  = value(forKeyPath: keyPath) as! NSObject?

                if  propertyValue != nil && propertyValue != cloudValue {
                    record[keyPath] = propertyValue as? CKRecordValue
                }
            }
        }
    }


    func useBest(record iRecord: CKRecord) {
        if  record != iRecord {
            if  let name = record[kpZoneName] as? String, name == kFirstIdeaTitle, record[kpZoneLink] != nil {
                bam("")
            }

            let      myDate = record?.modificationDate
            if  let newDate = iRecord.modificationDate,
                (myDate    == nil || myDate!.timeIntervalSince(newDate) < 0.000001) {

                orphan()    // sometimes a record contains a different parent or owner reference !!!!!

                record      = iRecord
            }
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


    // MARK:- states
    // MARK:-


    func    hasState(_ state: ZRecordState) -> Bool { return recordsManager?.hasZRecord(self, forAnyOf:[state]) ?? false }
    func    addState(_ state: ZRecordState)         {        recordsManager?.addZRecord(self,     for: [state]) }
    func removeState(_ state: ZRecordState)         {        recordsManager?.clearRecordName(recordName, for:[state]) }
    func clearAllStates()                           {        recordsManager?.clearRecordName(recordName, for: recordsManager?.allStates ?? []) }


    func needRoot()              {    addState(.needsRoot) }
    func needFound()             {    addState(.needsFound) }
    func needFetch()             {    addState(.needsFetch) }
    func needUnorphan()          {    addState(.needsUnorphan) }
    func markNotFetched()        {    addState(.notFetched) }
    func fetchBeforeSave()       {    addState(.requiresFetchBeforeSave) }
    func allowSaveWithoutFetch() { removeState(.requiresFetchBeforeSave)}
    func needCount()             {} //    if !gAssumeAllFetched { addState(.needsCount) } }
    func needColor()             {} //    if !gAssumeAllFetched { addState(.needsColor) } }
    func needTraits()            {} //    if !gAssumeAllFetched { addState(.needsTraits) } }
    func needParent()            {} //    if !gAssumeAllFetched { addState(.needsParent) } }
    func needWritable()          {} //    if !gAssumeAllFetched { addState(.needsWritable) } }


    func needSave() {
        allowSaveWithoutFetch()
        maybeNeedSave()
    }


    func needProgeny() {
//        if !gAssumeAllFetched {
//            addState(.needsProgeny)
//            removeState(.needsChildren)
//        }
    }


    func needDestroy() {
        if  canSaveWithoutFetch {
            addState   (.needsDestroy)
            removeState(.needsSave)
            removeState(.needsMerge)
        }
    }


    func needChildren() {
        if !isBookmark && // all bookmarks are childless, by design
            showChildren &&
            false, // !gAssumeAllFetched,
            !needsProgeny {
            addState(.needsChildren)
        }
    }


    func maybeNeedSave() {
        if !needsDestroy, !needsFetch, !needsSave, canSaveWithoutFetch {
            removeState(.needsMerge)
            addState   (.needsSave)
        }

        gFileManager.needWrite(for: databaseID)
    }


    func maybeMarkNotFetched() {
        if  record?.creationDate == nil {
            markNotFetched()
        }
    }


    func maybeNeedMerge() {
        if  isFetched, canSaveWithoutFetch, !needsSave, !needsMerge, !needsDestroy {
            addState(.needsMerge)
        }
    }


    func maybeMarkAsFetched() {
        if  let r = record {
            r.maybeMarkAsFetched(databaseID)
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


    // MARK:- files
    // MARK:-


    func type(from keyPath: String) -> ZStorageType? {
        let typeFromSuffixFollowing = { (iPrefix: String) -> (ZStorageType?) in
            let           parts = keyPath.components(separatedBy: iPrefix)

            if  parts.count > 1 {
                let      suffix = parts[1].lowercased()

                if  let    type = ZStorageType(rawValue: suffix) {
                    return type
                }
            }

            return nil
        }

        if            [kpParent, kpOwner]         .contains(keyPath) { return nil       // must be first ...
        } else if let type = ZStorageType(rawValue:         keyPath) { return type      // ZStorageType now ignores two (owner and parent)
        } else if let type = typeFromSuffixFollowing(  kpZonePrefix) { return type      // this deals with those two
        } else if let type = typeFromSuffixFollowing(kpRecordPrefix) { return type
        } else                                                       { return nil
        }
    }


    func extract(valueOf iType: ZStorageType, at iKeyPath: String) -> NSObject? {
        var value  = record?[iKeyPath] as? NSObject     // all properties are extracted from record, using iKeyPath as key

        if  value == nil, iKeyPath == kpRecordName {    // except for the record name
            value  = recordName as NSObject?
        }

        return value
    }


    func prepare(_ iObject: NSObject, of iType: ZStorageType) -> NSObject? {
        let object = iObject

        switch iType {
        case .link, .parentLink:
            if  let link = object as? String, !isValid(link) {
                return nil
            }
        default: break
        }

        return object
    }


    let kNeedsSeparator = ","


    func stringForNeeds(in iDatabaseID: ZDatabaseID) -> String? {
        if  let       r = record {
            let manager = gRemoteStoresManager.cloudManagerFor(iDatabaseID)
            let  states = manager.states(for: r)
            var   marks = [String] ()

            for state in states {
                marks.append("\(state.rawValue)")
            }

            if  marks.count > 0 {
                return marks.joined(separator: kNeedsSeparator)
            }
        }

        return nil
    }


    func addNeedsFromString(_ iNeeds: String) {
        let needs = iNeeds.components(separatedBy: kNeedsSeparator)

        temporarilyMarkNeeds {
            for need in needs {
                if  let state = ZRecordState(rawValue: need) {
                    addState(state)
                }
            }
        }
    }



    func storageDictionary(for iDatabaseID: ZDatabaseID) -> ZStorageDictionary? {
        if  let      name = recordName, !gFileManager.writtenRecordNames.contains(name) {
            let  keyPaths = cloudProperties() + [kpRecordName]
            var      dict = ZStorageDictionary()

            gFileManager.writtenRecordNames.append(name)

            for keyPath in keyPaths {
                if  let       type = type(from: keyPath),
                    let    extract = extract(valueOf: type, at: keyPath) ,
                    let   prepared = prepare(extract, of: type) {
                    dict[type]     = prepared
                }
            }

            if  let   needs  = stringForNeeds(in: iDatabaseID) {
                dict[.needs] = needs as NSObject?
            }

            return dict
        } else {
            return nil
        }
    }


    func setStorageDictionary(_ dict: ZStorageDictionary, of iRecordType: String, into iDatabaseID: ZDatabaseID) {
        databaseID       = iDatabaseID
        if  let     name = dict[.recordName] as? String, gRemoteStoresManager.recordsManagerFor(iDatabaseID)?.maybeCKRecordForRecordName(name) == nil {
            let ckRecord = CKRecord(recordType: iRecordType, recordID: CKRecordID(recordName: name)) // YIKES this may be wildly out of date

            for keyPath in cloudProperties() {
                if  let      type  = type(from: keyPath),
                    let    object  = dict[type],
                    let     value  = object as? CKRecordValue {
//                    var      path  = keyPath
//                    if       type == .owner,
//                        let string = gAuthorID {
//                        value      = string as CKRecordValue // CKReference(recordID: CKRecordID(recordName: string), action: .none)
//                        path       = "zoneAuthor"
//
//                        temporarilyMarkNeeds {
//                            needSave()
//                        }
//                    }

                    ckRecord[keyPath] = value
                }
            }

            record = ckRecord    // any subsequent changes into any of this object's cloudProperties will fetch / save this record from / to iCloud

            if  let needs = dict[.needs] as? String {
                addNeedsFromString(needs)
            }
        }
    }


    class func storageArray(for iZRecords: [ZRecord]?, from dbID: ZDatabaseID, allowEach: ZRecordToBooleanClosure? = nil) -> [ZStorageDictionary]? {
        if  let   zRecords = iZRecords,
            zRecords.count > 0 {
            var   array = [ZStorageDictionary] ()

            for zRecord in zRecords {
                if  (allowEach == nil || allowEach!(zRecord)),
                    let subDict = zRecord.storageDictionary(for: dbID) {
                    array.append(subDict)
                }
            }

            if  array.count > 0 {
                return array
            }
        }

        return nil
    }

}
