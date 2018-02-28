//
//  ZFileManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CoreFoundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


let gFileManager = ZFileManager()


class ZFileManager: NSObject {


    var            isWriting = [false, false] // not allow another save while file is being written
    var           needsWrite = [false, false]
    var filePaths: [String?] = [nil, nil]
    var _directoryURL : URL? = nil
    let              manager = FileManager.default


    var directoryURL: URL {
        get {
            if  _directoryURL == nil {
                _directoryURL  = createDataDirectory()
            }

            return _directoryURL!
        }
    }


    // MARK:- API
    // MARK:-


    func needWrite(for  databaseID: ZDatabaseID?) {
        if  let  dbID = databaseID,
            let index = indexOf(dbID) {
            needsWrite[index] = true
        }
    }


    func needsWrite(for  databaseID: ZDatabaseID?) -> Bool {
        if  let  dbID = databaseID,
            let index = indexOf(dbID) {
            return needsWrite[index]
        }

        return false
    }


    func write(for databaseID: ZDatabaseID?) {
        if  let           dbID = databaseID,
            dbID              != .favoritesID,
            gSaveMode         != .cloudOnly,
            let        index   = indexOf(dbID),
            needsWrite[index] == true,
            isWriting [index] == false {    // prevent write during write
            isWriting [index]  = true
            needsWrite[index]  = false
            var           dict = ZStorageDictionary ()
            let        manager = gRemoteStoresManager.cloudManagerFor(dbID)

            //////////////////////////////////////////////////
            // taake snapshots just before exit from method //
            //////////////////////////////////////////////////

            if  let   graph  = manager.rootZone?.storageDictionary(for: dbID)  {
                dict[.graph] = graph as NSObject
            }

            if  let   trash  = Zone.storageArray(for: manager.trashZone.children, from: dbID) {
                dict[.trash] = trash as NSObject
            }

            if  let   found  = Zone.storageArray(for: manager.lostAndFoundZone.children, from: dbID) {
                dict[.found] = found as NSObject
            }

            if  let   userID  = gUserRecordID {
                dict[.userID] = userID as NSObject
            }

            if                  dbID == .mineID {
                if  let    favorites  = gFavoritesManager.rootZone?.storageDictionary(for: dbID) {
                    dict [.favorites] = favorites as NSObject
                }

                if  let    bookmarks  = gBookmarksManager.storageArray(for: dbID) {
                    dict [.bookmarks] = bookmarks as NSObject
                }
            }

            BACKGROUND {
                dict[.date]  = Date().description as NSObject
                let jsonDict = self.jsonDictFrom(dict)
                let     path = self.filePath(for: index)
                let     data = try! JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)

                if  FileManager.default.createFile(atPath: path, contents: data) {}

                self .isWriting[index] = false // end prevention of write during write
            }
        }
    }


    func read(for databaseID: ZDatabaseID) {
        if  gFetchMode                  != .cloudOnly,
            databaseID                  != .favoritesID,
            let                  index   = indexOf(databaseID) {
            let                     path = filePath(for: index)
            let sections: [ZStorageType] = [.graph, .trash, .favorites, .bookmarks, .found]
            do {
                if  let data = FileManager.default.contents(atPath: path),
                    let json = try JSONSerialization.jsonObject(with: data) as? [String : NSObject] {
                    let dict = dictFromJSON(json)

                    for section in sections {
                        let dbID: ZDatabaseID = section == .favorites ? .favoritesID : databaseID
                        let           manager = gRemoteStoresManager.cloudManagerFor(dbID)
                        let  bookmarksSection = section == .bookmarks
                        var     parent: Zone? = nil

                        switch section {
                        case .found:   parent = manager.lostAndFoundZone
                        case .trash:   parent = manager.trashZone
                        default: break
                        }

                        if  let            value = dict[section] {
                            if  let      subDict = value as? ZStorageDictionary {
                                manager.rootZone = Zone(dict: subDict, in: databaseID)
                            } else if let  array = value as? [ZStorageDictionary], (parent != nil || bookmarksSection) {
                                for subDict in array {
                                    let zone = Zone(dict: subDict, in: databaseID)

                                    if bookmarksSection {
                                        gBookmarksManager.registerBookmark(zone)
                                    } else {
                                        parent?.addChildAndRespectOrder(zone)
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                print(error)    // de-serialization
            }
        }
    }
    

    // MARK:- internals
    // MARK:-


    func createDataDirectory() -> URL {
        let cacheURL = try! FileManager().url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directoryURL = cacheURL.appendingPathComponent("Focus", isDirectory: true)

        do {

            try manager.createDirectory(atPath: directoryURL.path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
        }

        return directoryURL
    }


    let normalExtension = ".focus"
    let backupExtension = ".backup"


    func filePath(for index: Int) -> String {
        var                   path  = filePaths[index]
        if  path                   == nil,
            let               name  = fileName(for: index) {
            let            fileURL  = directoryURL.appendingPathComponent(name + normalExtension)
            let          backupURL  = directoryURL.appendingPathComponent(name + backupExtension)
            let       backupExists  = manager.fileExists(atPath: backupURL.path)
            let      genericExists  = manager.fileExists(atPath:   fileURL.path)
            let      canUseGeneric  = index == 0 || gUserRecordID == nil
            path                    = fileURL.path

            do {
                if           canUseGeneric {
                    if       genericExists {
                        if    backupExists {
                            try manager.removeItem(at: backupURL)
                        }

                        try manager.copyItem(at: fileURL, to: backupURL)
                    } else if backupExists {
                        try manager.copyItem(at: backupURL, to: fileURL)        // should only happen when prior write fails due to power failure
                    } else {
                        manager.createFile(atPath: fileURL.path, contents: nil)
                    }
                } else {
                    let         newName = fileName(for: index, isGeneric: false)!
                    let      newFileURL = directoryURL.appendingPathComponent(newName + normalExtension)
                    let    newBackupURL = directoryURL.appendingPathComponent(newName + backupExtension)
                    let newBackupExists = manager.fileExists(atPath: newBackupURL.path)
                    let       newExists = manager.fileExists(atPath:   newFileURL.path)
                    path                = newFileURL.path

                    if              newExists {
                        if    newBackupExists {
                            try manager.removeItem(at: newBackupURL)
                        }

                        try manager.copyItem(at: newFileURL, to: newBackupURL)
                    } else if newBackupExists {
                        try manager.copyItem(at: newBackupURL, to: newFileURL)  // should only happen when prior write fails due to power failure
                    } else if  !genericExists {
                        manager.createFile(atPath: newFileURL.path, contents: nil)
                    } else {
                        try manager.moveItem(at: fileURL, to: newFileURL)
                        try manager.copyItem(at: newFileURL, to: newBackupURL)
                    }
                }
            } catch {
                print(error)
            }

            filePaths[index] = path
        }

        return path!
    }


    func databaseID(from index: Int) -> ZDatabaseID? {
        switch index {
        case 0:  return .everyoneID
        case 1:  return .mineID
        default: return nil
        }
    }


    func fileName(for index: Int, isGeneric: Bool = true) -> String? {
        if  let dbID = databaseID(from: index) {
            var name = dbID.rawValue

            if  dbID      == .mineID, !isGeneric,
                let userID = gUserRecordID {
                name       = "\(userID.hashValue)"
            }

            return name
        }

        return nil
    }


    func dictFromJSON(_ dict: [String : NSObject]) -> ZStorageDictionary {
        var                   result = ZStorageDictionary ()

        for (key, value) in dict {
            if  let       storageKey = ZStorageType(rawValue: key) {
                var        goodValue = value
                var       translated = false

                if  let string       = value as? String {
                    let parts        = string.components(separatedBy: kTimeInterval + ":")
                    if  parts.count > 1,
                        parts[0]    == "",
                        let interval = TimeInterval(parts[1]) {
                        goodValue    = Date(timeIntervalSinceReferenceDate: interval) as NSObject
                        translated   = true
                    }
                }

                if !translated {
                    if  let     subDict = value as? [String : NSObject] {
                        goodValue       = dictFromJSON(subDict) as NSObject
                    } else if let array = value as? [[String : NSObject]] {
                        var   goodArray = [ZStorageDictionary] ()

                        for subDict in array {
                            goodArray.append(dictFromJSON(subDict))
                        }

                        goodValue       = goodArray as NSObject
                    }
                }

                result[storageKey]  = goodValue
            }
        }

        return result
    }


    func jsonDictFrom(_ dict: ZStorageDictionary) -> [String : NSObject] {
        var deferals = ZStorageDictionary ()
        var   result = [String : NSObject] ()

        let closure = { (key: ZStorageType, value: Any) in
            var goodValue       = value
            if  let     subDict = value as? ZStorageDictionary {
                goodValue       = self.jsonDictFrom(subDict)
            } else if let  date = value as? Date {
                goodValue       = kTimeInterval + ":\(date.timeIntervalSinceReferenceDate)"
            } else if let array = value as? [ZStorageDictionary] {
                var jsonArray   = [[String : NSObject]] ()

                for subDict in array {
                    jsonArray.append(self.jsonDictFrom(subDict))
                }

                goodValue       = jsonArray
            }

            result[key.rawValue]   = (goodValue as! NSObject)
        }

        for (key, value) in dict {
            if [.children, .traits].contains(key) {
                deferals[key] = value
            } else {
                closure(key, value)
            }
        }

        for (key, value) in deferals {
            closure(key, value)
        }

        return result
    }

}
