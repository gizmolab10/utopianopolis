//
//  ZFiles.swift
//  Seriously
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
let gFilesURL : URL = {
	return try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
		.appendingPathComponent("Seriously", isDirectory: true)
}()

enum ZExportType: String {
	case eSeriously = "seriously"
	case eOutline   = "outline"
	case eEssay	    = "rtfd"
}

class ZFiles: NSObject {

	let              manager = FileManager.default
	var            isReading = [false, false]
    var            isWriting = [false, false] // not allow another save while file is being written
    var           needsWrite = [false, false]
    var   writtenRecordNames = [String] ()
    var filePaths: [String?] = [nil, nil]
    var           writeTimer : Timer?
	var           _assetsURL : URL?
	var            _filesURL : URL?
	var  approximatedRecords : Int { return fileSize / 900 }
	func imageURLInAssetsFolder(for fileName: String) -> URL { return assetsURL.appendingPathComponent(fileName) }

	var fileSize : Int {
		var result = 0

		do {
			for dbID in kAllDatabaseIDs {
				if  let      index = dbID.index,
					let    dbIndex = ZDatabaseIndex(rawValue: index) {
					let       path = filePath(for: dbIndex)
					let       dict = try manager.attributesOfItem(atPath: path)
					if  let length = dict[.size] as? Int {
						result    += length
					}
				}
			}
		} catch {
			printDebug(.dError, "\(error)")
		}

		return result
	}

    var isWritingNow: Bool {
        for writing in isWriting {
            if writing {
                return true
            }
        }

        return false
    }

	var filesURL: URL {
		if  _filesURL == nil {
			_filesURL  = createDataDirectory()
		}

		return _filesURL!
	}

	var assetsURL: URL {
		if  _assetsURL == nil {
			_assetsURL  = createAssetsDirectory()
		}

		return _assetsURL!
	}

    // MARK:- API
    // MARK:-

	func open() {
//		let panel = NSOpenPanel()
	}

	func writeAll() {
		needWrite(for: .mineID)
		needWrite(for: .everyoneID)
	}

    func needWrite(for  databaseID: ZDatabaseID?) {
        if  let  dbID = databaseID,
            let index = dbID.index {

            if !needsWrite[index] {
                needsWrite[index] = true
            } else if gWriteFiles, let timerID = ZTimerID.convert(from: databaseID) {
				gTimers.assureCompletion(for:   timerID, withTimeInterval: 5.0, restartTimer: true) {
					if  gIsEditIdeaMode {
						throw(ZInterruptionError.userInterrupted)
					} else {
						try self.writeToFile(from: databaseID)
					}
				}
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

	func writeToFile(from databaseID: ZDatabaseID?) throws {
		if  let     dbID = databaseID,
			dbID        != .favoritesID,
			let    index = dbID.index,
			let  dbIndex = ZDatabaseIndex(rawValue: index) {
				let path = filePath(for: dbIndex)
				try writeFile(at: path, from: databaseID)
		}
	}

	func readFile(into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		if  gReadFiles,
			databaseID  != .favoritesID,
			let    index = databaseID.index,
			let  dbIndex = ZDatabaseIndex(rawValue: index) {
			let 	path = filePath(for: dbIndex)

			try readFile(from: path, into: databaseID, onCompletion: onCompletion)
		} else {
			onCompletion?(0)
		}
	}

	func export(_ zone: Zone, toFileAs type: ZExportType) {
		let           panel = NSSavePanel()
		let          suffix = type.rawValue
		panel      .message = "Export as \(suffix)"
		gIsExportingToAFile = true

		if  let  name = zone.zoneName {
			panel.nameFieldStringValue = "\(name).\(suffix)"
		}

		panel.begin { result in
			if  result == .OK,
				let fileURL = panel.url {

				switch type {
					case .eOutline:
						let string = zone.outlineString()

						do {
							try string.write(to: fileURL, atomically: true, encoding: .utf8)
						} catch {
							printDebug(.dError, "\(error)")
						}
					case .eSeriously:
						gFiles.writtenRecordNames.removeAll()

						do {
							let     dict = try zone.storageDictionary()
							let jsonDict = dict.jsonDict
							let     data = try! JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)

							try data.write(to: fileURL)
						} catch {
							printDebug(.dError, "\(error)")
						}
					case .eEssay:
						if  let text = zone.note?.essayText {
							do {
								let fileData = try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType : NSAttributedString.DocumentType.rtfd])
								let  wrapper = FileWrapper(regularFileWithContents: fileData)

								try  wrapper.write(to: fileURL, options: .atomic, originalContentsURL: nil)

//								let fileText = String(data: fileData, encoding: .utf8)
//								try fileText?.write(to: fileURL, atomically: false, encoding: .utf8)

							} catch {
								printDebug(.dError, "\(error)")
							}
						}
				}
			}

			gIsExportingToAFile = false
		}
	}

    // MARK:- heavy lifting
    // MARK:-

	func writeFile(at path: String, from databaseID: ZDatabaseID?) throws {
		if  gWriteFiles,
			gHasFinishedStartup, // guarantee that file read finishes before this code runs
			let           dbID = databaseID,
			dbID              != .recentsID,
			dbID              != .favoritesID,
            let          cloud = gRemoteStorage.cloud(for: dbID),
			let        index   = dbID.index,
			needsWrite[index] == true,
			isWriting [index] == false {    // prevent write during write
			isWriting [index]  = true
			var           dict = ZStorageDictionary ()

			do {
				self.writtenRecordNames.removeAll()
				gRemoteStorage.recount()

				// //////////////////////////////////////////////
				// take snapshots just before exit from method //
				// //////////////////////////////////////////////

 				if  let     map  = try cloud.rootZone?.createStorageDictionary(for: dbID)  {
					dict[.graph] = map as NSObject
				}

				if  let   trash  = try cloud.trashZone?.createStorageDictionary(for: dbID) {
					dict[.trash] = trash as NSObject
				}

				if  let   destroy  = try cloud.destroyZone?.createStorageDictionary(for: dbID) {
					dict[.destroy] = destroy as NSObject
				}

				if  let   manifest  = try cloud.manifest?.createStorageDictionary(for: dbID) {
					dict[.manifest] = manifest as NSObject
				}

				if  let   lost  = try cloud.lostAndFoundZone?.createStorageDictionary(for: dbID) {
					dict[.lost] = lost as NSObject
				}

				if                 dbID == .mineID {
					if  let   favorites  = try gFavoritesRoot?.createStorageDictionary(for: .mineID) {
						dict[.favorites] = favorites as NSObject
					}

					if  let     recents  = try gRecentsRoot?.createStorageDictionary(for: .mineID) {
						dict[.recent]    = recents as NSObject
					}

					if  let   bookmarks  = try gBookmarks.storageArray(for: .mineID) {
						dict[.bookmarks] = bookmarks as NSObject
					}

					if  let      userID  = gUserRecordID {
						dict   [.userID] = userID as NSObject
					}
				}

				cloud.updateLastSyncDate()

				BACKGROUND {
					dict [.date] = cloud.lastSyncDate as NSObject
					let jsonDict = dict.jsonDict

					if  let data = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted) {
						let  url = URL(fileURLWithPath: path)

						try? data.write(to: url)
					} else {
						printDebug(.dFile, "json error on local storage")
					}

					self.needsWrite[index] = false
					self .isWriting[index] = false // end prevention of write during write
				}
			} catch {
				self     .isWriting[index] = false // end prevention of write during write

				throw(ZInterruptionError.userInterrupted)
			}
		}
	}

	func readFile(from path: String, into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		if  gReadFiles,
			databaseID      != .favoritesID,
			let       cloud  = gRemoteStorage.cloud(for: databaseID),
			let       index  = databaseID.index {
			isReading[index] = true
			typealias  types = [ZStorageType]
			let  keys: types = [.date, .lost, .graph, .trash, .destroy, .recent, .manifest, .favorites, .bookmarks ]

			if  let     data = FileManager.default.contents(atPath: path),
				data  .count > 0,
				let     json = try JSONSerialization.jsonObject(with: data) as? ZStringObjectDictionary {
				let     dict = self.dictFromJSON(json)

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
									let   manifest  = ZManifest.uniqueManifest(from: subDict, in: databaseID)
									cloud.manifest  = manifest
								}
							case .bookmarks:
								if let array = value as? [ZStorageDictionary] {
									for subDict in array {
										if  !databaseID.isDeleted(dict: subDict) {
											let zone = Zone.uniqueZone(from: subDict, in: databaseID)
											gBookmarks.addToReverseLookup(zone)
										}
									}
								}
							default:
								if  let subDict = value as? ZStorageDictionary, !databaseID.isDeleted(dict: subDict) {
									let    zone = Zone.uniqueZone(from: subDict, in: databaseID)

									zone.updateRecordName(for: key)

									switch key {
										case .lost:      cloud.lostAndFoundZone = zone
										case .graph:     cloud.rootZone         = zone
										case .trash:     cloud.trashZone        = zone
										case .recent:    cloud.recentsZone      = zone
										case .destroy:   cloud.destroyZone      = zone
										case .favorites: cloud.favoritesZone    = zone
										default: break
									}
								}
						}
					}
				}
			}

//			gRemoteStorage.zRecords(for: databaseID)?.removeDuplicates()
			cloud.recount()

			self.isReading[index] = false
		}

		onCompletion?(0)
	}

    func filePath(for index: ZDatabaseIndex) -> String {
        var                 path  = filePaths[index.rawValue]
        
        if                  path == nil,
            let             name  = fileName(for: index) {
            let         cloudName = fileName(for: index, isGeneric: false)!
            let        isEveryone = index == .everyoneIndex
            let        useGeneric = isEveryone || !gCloudStatusIsActive
            let   normalExtension = ".seriously"
            let   backupExtension = ".backup"
            let         backupURL = filesURL.appendingPathComponent(name + backupExtension)
            let    genericFileURL = filesURL.appendingPathComponent(name + normalExtension)
            let      cloudFileURL = filesURL.appendingPathComponent(cloudName + normalExtension)
            let    cloudBackupURL = filesURL.appendingPathComponent(cloudName + backupExtension)
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
                    } else if isEveryone,    let bundleFileURL = Bundle.main.url(forResource: "everyone", withExtension: "seriously") {
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
                printDebug(.dError, "\(error)")
            }

            filePaths[index.rawValue] = path
        }

        return path!
    }

    // MARK:- internals
    // MARK:-

    func createDataDirectory() -> URL {
        do {
            try manager.createDirectory(atPath: gFilesURL.path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            printDebug(.dError, "\(error)")
        }
        
        return gFilesURL
    }

	func createAssetsDirectory() -> URL {
		let url = gFilesURL.appendingPathComponent("assets")

		do {
			try manager.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
		} catch {
			printDebug(.dError, "\(error)")
		}

		return url
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
