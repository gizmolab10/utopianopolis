//
//  ZFiles.swift
//  Thoughtful
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

let gFiles    = ZFiles()
let gUseFiles = !kIsPhone

enum ZExportType: String {
	case eThoughtful = "thoughtful"
	case eOutline    = "outline"
	case eEssay		 = "rtf"
}

class ZFiles: NSObject {


    var            isReading = [false, false]
    var            isWriting = [false, false] // not allow another save while file is being written
    var           needsWrite = [false, false]
    var   writtenRecordNames = [String] ()
    var filePaths: [String?] = [nil, nil]
    var  writeTimer : Timer?
    var _directoryURL : URL?
    let              manager = FileManager.default


    var isWritingNow: Bool {
        for writing in isWriting {
            if writing {
                return true
            }
        }

        return false
    }


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


	func open() {
//		let panel = NSOpenPanel()
	}


    func deferWrite(for  databaseID: ZDatabaseID?, restartTimer: Bool = false) {
        if  writeTimer?.isValid ?? false || restartTimer {
            writeTimer?.invalidate()

            writeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { iTimer in
                if  gIsEditingText {
                    self.deferWrite(for: databaseID, restartTimer: true)
                } else {
                    self.writeToFile(from: databaseID)
                }
            }
        }
    }
	

    func needWrite(for  databaseID: ZDatabaseID?) {
        if  let  dbID = databaseID,
            let index = dbID.index {

            if !needsWrite[index] {
                needsWrite[index] = true
            } else {
                deferWrite(for: databaseID, restartTimer: true)
            }
        }
    }


    func isReading(for iDatabaseID: ZDatabaseID?) -> Bool {
        if  let  dbID = iDatabaseID,
            let index = dbID.index {
            return isReading[index]
        }

        return false
	}
	
    
    func writeAll() {
        for dbID in kAllDatabaseIDs {
            writeToFile(from: dbID)
        }
    }
    
	
	func writeToFile(from databaseID: ZDatabaseID?) {
		if  let     dbID = databaseID,
			dbID        != .favoritesID,
			let    index = dbID.index,
			let  dbIndex = ZDatabaseIndex(rawValue: index) {
				let path = filePath(for: dbIndex)
				writeFile(at: path, from: databaseID)
		}
	}
	
	
	func readFile(into databaseID: ZDatabaseID) {
		if  databaseID  != .favoritesID,
			let    index = databaseID.index,
			let  dbIndex = ZDatabaseIndex(rawValue: index) {
			let 	path = filePath(for: dbIndex)

			readFile(from: path, into: databaseID)
		}
	}


    // MARK:- heavy lifting
    // MARK:-


	func writeFile(at path: String, from databaseID: ZDatabaseID?) {
		if  let           dbID = databaseID,
			dbID              != .favoritesID,
            let        manager = gRemoteStorage.cloud(for: dbID),
			let        index   = dbID.index,
			needsWrite[index] == true,
			isWriting [index] == false {    // prevent write during write
			isWriting [index]  = true
			needsWrite[index]  = false
			var           dict = ZStorageDictionary ()
			
            FOREGROUND {
                self.writtenRecordNames.removeAll()
                gRemoteStorage.recount()

                // //////////////////////////////////////////////
                // take snapshots just before exit from method //
                // //////////////////////////////////////////////

                if  let   graph  = manager.rootZone?.storageDictionary(for: dbID)  {
                    dict[.graph] = graph as NSObject
                }

                if  let   trash  = manager.trashZone?.storageDictionary(for: dbID) {
                    dict[.trash] = trash as NSObject
                }

                if  let   destroy  = manager.destroyZone?.storageDictionary(for: dbID) {
                    dict[.destroy] = destroy as NSObject
                }

                if  let   manifest  = manager.manifest?.storageDictionary(for: dbID) {
                    dict[.manifest] = manifest as NSObject
                }

                if  let   lost  = manager.lostAndFoundZone?.storageDictionary(for: dbID) {
                    dict[.lost] = lost as NSObject
                }

                if                 dbID == .mineID {
                    if  let   favorites  = gFavoritesRoot?.storageDictionary(for: dbID) {
                        dict[.favorites] = favorites as NSObject
                    }

                    if  let   bookmarks  = gBookmarks.storageArray(for: dbID) {
                        dict[.bookmarks] = bookmarks as NSObject
                    }

                    if  let       userID  = gUserRecordID {
                        dict    [.userID] = userID as NSObject
                    }
                }

                manager.updateLastSyncDate()

                BACKGROUND(after: 1.0) {
                    dict [.date] = manager.lastSyncDate as NSObject
                    let jsonDict = self.jsonDictFrom(dict)

                    if  let data = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted) {
                        let  url = URL(fileURLWithPath: path)

                        try? data.write(to: url)
                    } else {
						printDebug(.error, "ahah")
                    }

                    self.isWriting[index] = false // end prevention of write during write
                }
            }
		}
	}
	
	
	func readFile(from path: String, into databaseID: ZDatabaseID) {
		if  gUseFiles,
            databaseID      != .favoritesID,
            let       cloud  = gRemoteStorage.cloud(for: databaseID),
			let       index  = databaseID.index {
			isReading[index] = true
			typealias  types = [ZStorageType]
			let  keys: types = [.date, .manifest, .lost, .graph, .trash, .destroy, .favorites, .bookmarks ]
			
            FOREGROUND {
                do {
                    if  let   data = FileManager.default.contents(atPath: path),
                        data.count > 0,
                        let   json = try JSONSerialization.jsonObject(with: data) as? ZStringObjectDictionary {
                        let   dict = self.dictFromJSON(json)

                        for key in keys {
                            if  let value = dict[key] {

                                switch key {
                                case .date:
                                    if  let date = value as? Date {
                                        cloud.lastSyncDate = date
                                    }
                                case .manifest:
                                    if  cloud.manifest == nil,
                                        let    subDict  = value as? ZStorageDictionary {
                                        let   manifest  = ZManifest(dict: subDict, in: databaseID)
                                        cloud.manifest  = manifest
                                    }
                                case .bookmarks:
                                    if let array = value as? [ZStorageDictionary] {
                                        for subDict in array {
                                            if  !databaseID.isDeleted(dict: subDict) {
                                                let zone = Zone(dict: subDict, in: databaseID)
                                                
                                                gBookmarks.registerBookmark(zone)
                                            }
                                        }
                                    }
                                default:
                                    if  let subDict = value as? ZStorageDictionary,
                                        !databaseID.isDeleted(dict: subDict) {
                                        let zone = Zone(dict: subDict, in: databaseID)
                                        
                                        zone.updateRecordName(for: key)
                                        
                                        switch key {
										case .lost:      cloud.lostAndFoundZone = zone
                                        case .graph:     cloud.rootZone         = zone
                                        case .trash:     cloud.trashZone        = zone
                                        case .destroy:   cloud.destroyZone      = zone
                                        case .favorites: gFavoritesRoot         = zone
                                        default: break
                                        }
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    printDebug(.error, "\(error)")    // de-serialization
                }

                gRemoteStorage.zRecords(for: databaseID)?.removeDuplicates()

                self.isReading[index] = false
            }
		}
	}
	

    func filePath(for index: ZDatabaseIndex) -> String {
        var                 path  = filePaths[index.rawValue]
        
        if                  path == nil,
            let             name  = fileName(for: index) {
            let         cloudName = fileName(for: index, isGeneric: false)!
            let        isEveryone = index == .everyoneIndex
            let        useGeneric = isEveryone || !gCanAccessMyCloudDatabase
            let   normalExtension = ".thoughtful"
            let   backupExtension = ".backup"
            let         backupURL = directoryURL.appendingPathComponent(name + backupExtension)
            let    genericFileURL = directoryURL.appendingPathComponent(name + normalExtension)
            let      cloudFileURL = directoryURL.appendingPathComponent(cloudName + normalExtension)
            let    cloudBackupURL = directoryURL.appendingPathComponent(cloudName + backupExtension)
            let cloudBackupExists = manager.fileExists(atPath: cloudBackupURL.path)
            var     genericExists = manager.fileExists(atPath: genericFileURL.path)
            let      backupExists = manager.fileExists(atPath:      backupURL.path)
            let       cloudExists = manager.fileExists(atPath:   cloudFileURL.path)
            path                  = genericFileURL.path

            do {
                if   useGeneric {
                    if !genericExists && (cloudExists || cloudBackupExists) && !isEveryone {
                        if                cloudExists {
                            try manager.moveItem(at: cloudFileURL,   to: genericFileURL)

                            if      cloudBackupExists {
                                try manager.removeItem(at: cloudBackupURL)
                            }

                            genericExists = true
                        } else if   cloudBackupExists {
                            try manager.moveItem(at: cloudBackupURL, to: genericFileURL)
                            
                            genericExists = true
                        }
                    }

                    if     genericExists {
                        if  backupExists {
                            try manager.removeItem(at: backupURL)                       // remove before replacing, below
                        }

                        try manager.copyItem(at: genericFileURL,     to: backupURL)
                    } else if backupExists {
                        try manager.copyItem(at: backupURL,     to: genericFileURL)     // should only happen when prior write fails due to power failure
                    } else if isEveryone,    let bundleFileURL = Bundle.main.url(forResource: "everyone", withExtension: "thoughtful") {
                        try manager.copyItem(at: bundleFileURL, to: genericFileURL)
                    } else {
                        manager.createFile(atPath: genericFileURL.path, contents: nil)
                    }
                } else {
                    path        = cloudFileURL.path

                    if            cloudExists {
                        if  cloudBackupExists {
                            try manager.removeItem(at:  cloudBackupURL)             // remove before replacing, below
                        }

                        try manager.copyItem(at:   cloudFileURL, to: cloudBackupURL)
                    } else if cloudBackupExists {
                        try manager.copyItem(at: cloudBackupURL, to:   cloudFileURL) // should only happen when prior write fails due to power failure
                    } else if    !genericExists {
                        manager.createFile(atPath: cloudFileURL.path, contents: nil)
                    } else {
                        try manager.moveItem(at: genericFileURL, to:   cloudFileURL)
                        try manager.copyItem(at:   cloudFileURL, to: cloudBackupURL)
                        
                        genericExists = false
                    }
                    
                    if  backupExists {
                        try manager.removeItem(at:      backupURL)
                    }

                    if  genericExists {
                        try manager.removeItem(at: genericFileURL)
                    }
                }
            } catch {
                printDebug(.error, "\(error)")
            }

            filePaths[index.rawValue] = path
        }

        return path!
    }


    // MARK:- internals
    // MARK:-
    
    
    func createDataDirectory() -> URL {
        let cacheURL = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directoryURL = cacheURL.appendingPathComponent("Thoughtful", isDirectory: true)
        
        do {
            try manager.createDirectory(atPath: directoryURL.path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            printDebug(.error, "\(error)")
        }
        
        return directoryURL
    }
    

    func fileName(for index: ZDatabaseIndex, isGeneric: Bool = true) -> String? {
        if  let dbID = index.databaseID {
            var name = dbID.rawValue

            if  dbID      == .mineID, !isGeneric,
                let userID = gUserRecordID {
                name       = userID
            }

            return name
        }

        return nil
    }

}
