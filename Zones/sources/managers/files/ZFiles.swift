//
//  ZFileManager.swift
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


let gFiles = ZFiles()


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


    func showInFinder() {
        directoryURL.absoluteString.openAsURL()
    }


	func open() {
//		let panel = NSOpenPanel()
	}

	
	func saveAs() {
		let panel = NSSavePanel()
		panel.nameFieldStringValue = "mine.thoughtful"
		panel.begin { (response: NSApplication.ModalResponse) in
			if  let path = panel.url?.absoluteString {
				self.needWrite(for: .mineID)
				self.writeFile(at: path, from: .mineID)
			}
		}
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
            let index = index(of: dbID) {

            if !needsWrite[index] {
                needsWrite[index] = true
            } else {
                deferWrite(for: databaseID, restartTimer: true)
            }
        }
    }


    func isReading(for iDatabaseID: ZDatabaseID?) -> Bool {
        if  let databaseID = iDatabaseID,
            let      index = index(of: databaseID) {
            return isReading[index]
        }

        return false
	}
	
	
	func writeToFile(from databaseID: ZDatabaseID?) {
		if  let     dbID = databaseID,
			dbID        != .favoritesID,
			let    index = index(of: dbID),
			let  dbIndex = ZDatabaseIndex(rawValue: index) {
				let path = filePath(for: dbIndex)
				writeFile(at: path, from: databaseID)
		}
	}
	
	
	func readFile(into databaseID: ZDatabaseID) {
		if  databaseID  != .favoritesID,
			let    index = index(of: databaseID),
			let  dbIndex = ZDatabaseIndex(rawValue: index) {
			let 	path = filePath(for: dbIndex)

			readFile(from: path, into: databaseID)
		}
	}


    func importFromFile(asOutline: Bool, insertInto: Zone, onCompletion: Closure?) {
        if !asOutline,
            let  window = gApplication.mainWindow {
            let  suffix = asOutline ? "outline" : "thoughtful"
            let   panel = NSOpenPanel()
            panel.title = "Import as \(suffix)"
            panel.resolvesAliases = false
            panel.canResolveUbiquitousConflicts = false
            panel.canDownloadUbiquitousContents = false

            panel.beginSheetModal(for: window) { (result) in
                do {
                    if  result.rawValue   == NSFileHandlingPanelOKButton,
                        panel.urls.count > 0 {
                        let  path = panel.urls[0].path

                        if  let   data = FileManager.default.contents(atPath: path),
                            data.count > 0,
                            let   dbID = insertInto.databaseID,
                            let   json = try JSONSerialization.jsonObject(with: data) as? [String : NSObject] {
                            let   dict = self.dictFromJSON(json)
                            let   zone = Zone(dict: dict, in: dbID)

                            insertInto.addChild(zone, at: 0)
                            onCompletion?()
                        }
                    }
                } catch {
                    print(error)    // de-serialization
                }
            }
        }
    }


    func exportToFile(asOutline: Bool, for iFocus: Zone) {
        let    suffix = asOutline ? "outline" : "thoughtful"
        let     panel = NSSavePanel()
        panel.message = "Export as \(suffix)"

        if  let  name = iFocus.zoneName {
            panel.nameFieldStringValue = "\(name).\(suffix)"
        }

        panel.begin { (result) -> Void in
            if  result.rawValue == NSFileHandlingPanelOKButton,
                let filename = panel.url {

                if  asOutline {
                    let string = iFocus.outlineString()

                    do {
                        try string.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
                    } catch {
                        // failed to write file (bad permissions, bad filename etc.)
                    }
                } else {
                    self.writtenRecordNames.removeAll()

                    let     dict = iFocus.storageDictionary
                    let jsonDict = self.jsonDictFrom(dict)
                    let     data = try! JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)

                    do {
                        try data.write(to: filename)
                    } catch {
                        print("ahah")
                    }
                }
            }
        }
    }


    // MARK:- internals
    // MARK:-


	func writeFile(at path: String, from databaseID: ZDatabaseID?) {
		if  let           dbID = databaseID,
			dbID              != .favoritesID,
            let        manager = gRemoteStorage.cloud(for: dbID),
			let        index   = index(of: dbID),
			needsWrite[index] == true,
			isWriting [index] == false {    // prevent write during write
			isWriting [index]  = true
			needsWrite[index]  = false
			var           dict = ZStorageDictionary ()
			
            FOREGROUND {
                gControllers.signalFor(nil, regarding: .eDebug)
                self.writtenRecordNames.removeAll()
                gRemoteStorage.recount()

                /////////////////////////////////////////////////
                // take snapshots just before exit from method //
                /////////////////////////////////////////////////

                if  let   graph  = manager.rootZone?.storageDictionary(for: dbID)  {
                    dict[.graph] = graph as NSObject
                }

                if  let   trash  = manager.trashZone?.storageDictionary(for: dbID) {
                    dict[.trash] = trash as NSObject
                }

                if  let   destroy  = manager.destroyZone?.storageDictionary(for: dbID) {
                    dict[.destroy] = destroy as NSObject
                }

                if  let   lost  = manager.lostAndFoundZone?.storageDictionary(for: dbID) {
                    dict[.lost] = lost as NSObject
                }

                if                 dbID == .mineID {
                    if  let   favorites  = manager.favoritesZone?.storageDictionary(for: dbID) {
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
                    let     data = try! JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
                    let      url = URL(fileURLWithPath: path)

                    do {
                        try data.write(to: url)
                    } catch {
                        print("ahah")
                    }

                    self.isWriting[index] = false // end prevention of write during write

                    gControllers.signalFor(nil, regarding: .eDebug)
                }
            }
		}
	}
	
	
	func readFile(from path: String, into databaseID: ZDatabaseID) {
		if  databaseID      != .favoritesID,
            let      manager = gRemoteStorage.cloud(for: databaseID),
			let       index  = index(of: databaseID) {
			isReading[index] = true
			typealias  types = [ZStorageType]
			let  keys: types = [.date, .lost, .graph, .trash, .destroy, .favorites, .bookmarks ]
			
            FOREGROUND {
                do {
                    if  let   data = FileManager.default.contents(atPath: path),
                        data.count > 0,
                        let   json = try JSONSerialization.jsonObject(with: data) as? [String : NSObject] {
                        let   dict = self.dictFromJSON(json)

                        for key in keys {
                            if  let   value = dict[key] {

                                if let date = value as? Date {
                                    manager.lastSyncDate = date
                                } else if let subDict = value as? ZStorageDictionary {
                                    let zone = Zone(dict: subDict, in: databaseID)

                                    switch key {
                                    case .graph:     manager        .rootZone = zone; gControllers.signalFor(nil, regarding: .eRelayout)
                                    case .trash:     manager       .trashZone = zone
                                    case .destroy:   manager     .destroyZone = zone
                                    case .favorites: manager   .favoritesZone = zone
                                    case .lost:      manager.lostAndFoundZone = zone
                                    default: break
                                    }
                                } else if let array = value as? [ZStorageDictionary] {
                                    for subDict in array {
                                        let zone = Zone(dict: subDict, in: databaseID)

                                        gBookmarks.registerBookmark(zone)
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    print(error)    // de-serialization
                }

                gRemoteStorage.recordsFor(databaseID)?.removeDuplicates()

                self.isReading[index] = false
            }
		}
	}
	

    func createDataDirectory() -> URL {
        let cacheURL = try! FileManager().url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directoryURL = cacheURL.appendingPathComponent("Thoughtful", isDirectory: true)

        do {
            try manager.createDirectory(atPath: directoryURL.path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
        }

        return directoryURL
    }


    let normalExtension = ".thoughtful"
    let backupExtension = ".backup"


    func filePath(for index: ZDatabaseIndex) -> String {
        var                 path  = filePaths[index.rawValue]
        if                  path == nil,
            let             name  = fileName(for: index) {
            let         cloudName = fileName(for: index, isGeneric: false)!
            let        isEveryone = index == .everyoneIndex
            let        useGeneric = isEveryone || !gCloudAccountIsActive
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
                print(error)
            }

            filePaths[index.rawValue] = path
        }

        return path!
    }


    func fileName(for index: ZDatabaseIndex, isGeneric: Bool = true) -> String? {
        if  let dbID = databaseIDFrom(index) {
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
