//  ZRecord.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 9/19/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


class ZRecord: NSObject {
    

    var             _record: CKRecord?
    var   writtenModifyDate: Date?
    var          kvoContext: UInt8 = 1
    var          databaseID: ZDatabaseID?
    var  isInPublicDatabase: Bool               { guard let dbID = databaseID else { return false } ; return dbID == .everyoneID }
    var     showingChildren: Bool               { return isExpanded(self.recordName) }
    var   isRootOfFavorites: Bool               { return record != nil && recordName == kFavoritesRootName }
    var          isBookmark: Bool               { return record?.isBookmark ?? false }
    var              isRoot: Bool               { return record != nil && kRootNames.contains(recordName!) }
    var           isFetched: Bool               { return !hasState(.notFetched) }
    var           needsSave: Bool               { return  hasState(.needsSave) }
    var           needsRoot: Bool               { return  hasState(.needsRoot) }
    var          notFetched: Bool               { return  hasState(.notFetched) }
    var          needsCount: Bool               { return  hasState(.needsCount) }
    var          needsColor: Bool               { return  hasState(.needsColor) }
    var          needsFetch: Bool               { return  hasState(.needsFetch) }
    var          needsMerge: Bool               { return  hasState(.needsMerge) }
    var         needsTraits: Bool               { return  hasState(.needsTraits) }
    var         needsParent: Bool               { return  hasState(.needsParent) }
    var        needsDestroy: Bool               { return  hasState(.needsDestroy) }
    var        needsProgeny: Bool               { return  hasState(.needsProgeny) }
    var       needsWritable: Bool               { return  hasState(.needsWritable) }
    var       needsChildren: Bool               { return  hasState(.needsChildren) }
    var      needsBookmarks: Bool               { return  hasState(.needsBookmarks) }
    var canSaveWithoutFetch: Bool               { return !hasState(.requiresFetchBeforeSave) }
    var   storageDictionary: ZStorageDictionary { if let dbID = databaseID, let dict = storageDictionary(for: dbID, includeRecordName: false) { return dict } else { return [:] } }
    var             records: ZRecords?          { return gRemoteStorage.zRecords(for: databaseID) }
    var               cloud: ZCloud?            { return records as? ZCloud }
    var          recordName: String?            { return record?.recordID.recordName }
    var       unwrappedName: String             { return emptyName }
    var           emptyName: String             { return "" }
    

    var record: CKRecord? {
        get {
            return _record
        }

        set {
            if  _record != newValue {

                ///////////////////////////////////////////
                // old registrations are no longer valid //
                ///////////////////////////////////////////

                clearAllStates() // is this needed pr wanted?
                gBookmarks.unregisterBookmark(self as? Zone)
                cloud?.unregisterCKRecord(_record)

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
                    let name = zone?.zoneName ?? recordName ?? emptyName

                    if       !canSaveWithoutFetch &&  isFetched {
                        bam("new record, ALLOW SAVE WITHOUT FETCH " + name)
                        allowSaveWithoutFetch()
                    } else if canSaveWithoutFetch && notFetched {
                        bam("require FETCH BEFORE SAVE " + name)
                        fetchBeforeSave()

                        if  name != emptyName || recordName == kRootName {
                            bam("new named record, should ALLOW SAVING")
                        }
                    }
                }
            }
        }
    }


    func isExpanded(_ iRecordName: String?) -> Bool {
        if  let                      name   = iRecordName,
            gExpandedZones.firstIndex(of: name) != nil {
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
            while let index = expansionSet.firstIndex(of: name) {
                expansionSet.remove(at: index)
            }
        }

        if  gExpandedZones.count != expansionSet.count {
            gExpandedZones        = expansionSet
        }
    }


    func toggleChildrenVisibility() {
        if  showingChildren {
            concealChildren()
        } else {
            revealChildren()
        }
    }


    // MARK:- overrides
    // MARK:-


    override init() {
        super.init()
        self.setupKVO();
    }


    convenience init(record: CKRecord?, databaseID: ZDatabaseID?) {
        self.init()

        self.databaseID = databaseID

        if  let r = record {
            self.record = r

            unorphan()
        }
    }


    deinit {
        teardownKVO()
    }


    func orphan() {}
    func unorphan() {}
    func maybeNeedRoot() {}
    func debug(_  iMessage: String) {}
    func cloudProperties() -> [String] { return [] }
    func ignoreKeyPathsForStorage() -> [String] { return [kpParent, kpOwner] }
    func   register() -> Bool { return cloud?.registerZRecord(self) ?? false }
    func unregister() { cloud?.unregisterZRecord(self) }
    func hasMissingChildren() -> Bool { return true }
    func hasMissingProgeny()  -> Bool { return true }


    // MARK:- properties
    // MARK:-


    func setupLinks() {}


    func temporarilyMarkNeeds(_ closure: Closure) {
        cloud?.temporarilyForRecordNamed(recordName, ignoreNeeds: false, closure)
    }


    func temporarilyIgnoreNeeds(_ closure: Closure) {
        cloud?.temporarilyForRecordNamed(recordName, ignoreNeeds: true, closure)
    }


    func updateInstanceProperties() {
        if  let r = record {
            for keyPath in cloudProperties() {
                if  let    cloudValue  = r[keyPath] as! NSObject? {
                    let propertyValue  = value(forKeyPath: keyPath) as! NSObject?

                    if  propertyValue != cloudValue {
                        setValue(cloudValue, forKeyPath: keyPath)
                    }
                }
            }
        }
    }


    func updateCKRecordProperties() {
        if  let r = record {
            for keyPath in cloudProperties() {
                let    cloudValue  = r[keyPath] as! NSObject?
                let propertyValue  = value(forKeyPath: keyPath) as! NSObject?

                if  propertyValue != nil && propertyValue != cloudValue {
                    r[keyPath] = propertyValue as? CKRecordValue
                }
            }
        }
    }


    func useBest(record iRecord: CKRecord) {
        let myDate      = record?.modificationDate ?? writtenModifyDate
        if  record     != iRecord,
            let newDate = iRecord.modificationDate,
            (myDate    == nil || newDate.timeIntervalSince(myDate!) > 10.0) {
            
            if  let r = record,
                r.recordID.recordName != iRecord.recordID.recordName {
                records?.addCKRecord(record, for: [.needsDestroy])
            }

            record      = iRecord
        }
    }


    func copy(into iCopy: ZRecord) {
        iCopy.maybeNeedSave() // so KVO won't set needsMerge
        updateCKRecordProperties()
        record?.copy(to: iCopy.record, properties: cloudProperties())
        iCopy.updateInstanceProperties()
    }


    func mergeIntoAndTake(_ iRecord: CKRecord) {
        updateCKRecordProperties()

        if  let r = record, r.copy(to: iRecord, properties: cloudProperties()) {
            record  = iRecord

            maybeNeedSave()
        }
    }


    // MARK:- states
    // MARK:-


    func    hasState(_ state: ZRecordState) -> Bool { return records?.hasZRecord(self, forAnyOf:[state]) ?? false }
    func    addState(_ state: ZRecordState)         {        records?.addZRecord(self,     for: [state]) }
    func removeState(_ state: ZRecordState)         {        records?.clearRecordName(recordName, for:[state]) }
    func clearAllStates()                           {        records?.clearRecordName(recordName, for: records?.allStates ?? []) }


    func needRoot()              {    addState(.needsRoot) }
    func needFound()             {    addState(.needsFound) }
    func needFetch()             {    addState(.needsFetch) }
    func needCount()             {    addState(.needsCount) }
    func needUnorphan()          {    addState(.needsUnorphan) }
    func markNotFetched()        {    addState(.notFetched) }
    func fetchBeforeSave()       {    addState(.requiresFetchBeforeSave) }
    func allowSaveWithoutFetch() { removeState(.requiresFetchBeforeSave)}
    func needColor()             {} //    if !gAssumeAllFetched { addState(.needsColor) } }
    func needTraits()            {} //    if !gAssumeAllFetched { addState(.needsTraits) } }
    func needParent()            {} //    if !gAssumeAllFetched { addState(.needsParent) } }
    func needWritable()          {} //    if !gAssumeAllFetched { addState(.needsWritable) } }


    func needSave() {
        allowSaveWithoutFetch()
        maybeNeedSave()
    }


    func needDestroy() {
        if  canSaveWithoutFetch {
            addState   (.needsDestroy)
            removeState(.needsSave)
            removeState(.needsMerge)
        }
    }

    
    func needProgeny() {
        //        if !gAssumeAllFetched {
        //            addState(.needsProgeny)
        //            removeState(.needsChildren)
        //        }
    }

    
    func reallyNeedProgeny() {
        addState(.needsProgeny)
        removeState(.needsChildren)
    }

    
    func needChildren() {
        if !isBookmark && // all bookmarks are childless, by design
            showingChildren &&
            false, // !gAssumeAllFetched,
            !needsProgeny {
            addState(.needsChildren)
        }
    }

    
    func reallyNeedChildren() {
        if !isBookmark && // all bookmarks are childless, by design
            showingChildren &&
            !needsProgeny {
            addState(.needsChildren)
        }
    }


    func maybeNeedSave() {
        if !needsDestroy, !needsSave, (canSaveWithoutFetch || !needsFetch) {
            removeState(.needsMerge)
            addState   (.needsSave)
        }

        gFiles.needWrite(for: databaseID)
    }


    func deferWrite() {
        gFiles.deferWrite(for: databaseID)
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
        cloud?.setIntoObject(self, value: value, for: property)
    }


    func get(propertyName: String) {
        cloud?.getFromObject(self, valueForPropertyName: propertyName)
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
        func extractType(_ ignored: String) -> (ZStorageType?) {
            let     parts = keyPath.lowercased().components(separatedBy: ignored)

            for     part in parts {
                if  part.length > 0,
                    let type = ZStorageType(rawValue: part) {
                    return type
                }
            }

            return nil
        }

        if              ignoreKeyPathsForStorage().contains(keyPath) { return nil       // must be first ... ZStorageType now ignores two (owner and parent)
        } else if keyPath == kpModificationDate                      { return .date
        } else if let type = ZStorageType(rawValue:         keyPath) { return type
        } else if let type = extractType(  kpZonePrefix) { return type      // this deals with those two
        } else if let type = extractType(kpRecordPrefix) { return type
        } else                                                       { return nil
        }
    }


    func extract(valueOf iType: ZStorageType, at iKeyPath: String) -> NSObject? {     // all properties are extracted from record, using iKeyPath as key
        switch iKeyPath {
        case kpRecordName:       return recordName as NSObject?      // except for the record name
        case kpModificationDate: return record?.modificationDate?.timeIntervalSince1970 as Double? as NSObject?
        default:                 return record?[iKeyPath] as? NSObject
        }
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
        if  let       r = record,
            let manager = gRemoteStorage.cloud(for: iDatabaseID) {
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


    func storageDictionary(for iDatabaseID: ZDatabaseID, includeRecordName: Bool = true) -> ZStorageDictionary? {
        if  let      name = recordName, !gFiles.writtenRecordNames.contains(name) {
            let  keyPaths = cloudProperties() + (includeRecordName ? [kpRecordName] : []) + [kpModificationDate]
            var      dict = ZStorageDictionary()

            gFiles.writtenRecordNames.append(name)

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
        databaseID   = iDatabaseID
        let     name = dict[.recordName] as? String
        var ckRecord = CKRecord(recordType: iRecordType)

        if  name == nil || gRemoteStorage.zRecords(for: iDatabaseID)?.maybeCKRecordForRecordName(name) == nil {
            if  let recordName = name {
                ckRecord = CKRecord(recordType: iRecordType, recordID: CKRecord.ID(recordName: recordName)) // YIKES this may be wildly out of date
            }
            
            for keyPath in cloudProperties() + [kpModificationDate] {
                if  let      type  = type(from: keyPath),
                    let    object  = dict[type],
                    let     value  = object as? CKRecordValue {

                    if  type != .date {
                        ckRecord[keyPath]  = value
                    } else if let interval = object as? Double {
                        writtenModifyDate = Date(timeIntervalSince1970: interval)
                    }
                }
            }

            record = ckRecord    // any subsequent changes into any of this object's cloudProperties will fetch / save this record from / to iCloud

            if  let needs = dict[.needs] as? String {
                addNeedsFromString(needs)
            }
        }
    }


    class func storageArray(for iItems: [AnyObject]?, from dbID: ZDatabaseID, includeRecordName: Bool = true, allowEach: ZRecordToBooleanClosure? = nil) -> [ZStorageDictionary]? {
        if  let   items = iItems,
            items.count > 0 {
            var   array = [ZStorageDictionary] ()

            for item in items {
                var dict: ZStorageDictionary?

                if  let zRecord = item as? ZRecord,
                    (allowEach == nil || allowEach!(zRecord)) {
                    dict = zRecord.storageDictionary(for: dbID, includeRecordName: includeRecordName)
//                } else if let reference = item as? CKRecord.Reference {
//                    dict = reference.storageDictionary()
                }

                if  dict != nil {
                    array.append(dict!)
                }
            }

            if  array.count > 0 {
                return array
            }
        }

        return nil
    }

}
