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
	return try! gFileManager.url(for: .applicationSupportDirectory, in: .allDomainsMask, appropriateFor: nil, create: true)
		.appendingPathComponent("Seriously", isDirectory: true) // .replacingPathComponent("com.seriously.mac", with: "Seriously")
}()

enum ZExportType: String {
	case eSeriously = "seriously"
	case eOutline   = "outline"
	case eEssay	    = "rtfd"
	case eCSV       = "csv"
}

enum ZInterruptionError : Error {
	case userInterrupted
}

class ZFiles: NSObject {

	var                       isReading  = [false, false, false]
    var  filePaths:           [String?]  = [nil, nil, nil]
	var                         hasMine  : Bool  { return fileExistsFor(.mineIndex) }
	lazy var                  assetsURL  : URL = { return createAssetsDirectory() }()
	lazy var                   filesURL  : URL = { return createDataDirectory() }()
	func assetURL(for fileName: String) -> URL   { return assetsURL.appendingPathComponent(fileName) }
	
	lazy var totalFilesSize : Int = {
		var result = 0

		for databaseID in kAllDatabaseIDs {
			result += fileSizeFor(databaseID)
		}

		return result
	}()

	func fileSizeFor(_ databaseID: ZDatabaseID) -> Int {
		var         result     = 0
		do {
			if  let      index = databaseID.index,
				let    dbIndex = ZDatabaseIndex(rawValue: index) {
				let       path = filePath(for: dbIndex)
				let       dict = try gFileManager.attributesOfItem(atPath: path)
				if  let length = dict[.size] as? Int {
					result     = length
				}
			}
		} catch {
			printDebug(.dError, "\(error)")
		}

		return result
	}

    // MARK: - API
    // MARK: -

	func fileExistsFor(_ dbIndex: ZDatabaseIndex) -> Bool {
		if  let  gName = fileName(for: dbIndex),
			let   name = fileName(for: dbIndex, isGeneric: false) {
			let extend = "seriously"
			let   gURL = filesURL.appendingPathComponent(gName).appendingPathExtension(extend)
			let    url = filesURL.appendingPathComponent( name).appendingPathExtension(extend)
			return url.fileExists || gURL.fileExists
		}

		return false
	}

    func isReading(for iDatabaseID: ZDatabaseID?) -> Bool {
        if  let  databaseID = iDatabaseID,
            let index = databaseID.index {
            return isReading[index]
        }

        return false
	}

	func writeToFile(from iDatabaseID: ZDatabaseID?) throws {
		if  gWriteFiles,
			let databaseID = iDatabaseID,
			databaseID    != .favoritesID,
			let      index = databaseID.index,
			let    dbIndex = ZDatabaseIndex(rawValue: index) {
			let       path = filePath(for: dbIndex)
			try writeFile(at: path, from: databaseID)
		}
	}

	func readFile(into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		if  databaseID != .favoritesID,
			let  index  = databaseID.databaseIndex {
			let   path  = filePath(for: index)

			try readFile(from: path, into: databaseID, onCompletion: onCompletion)
		} else {
			onCompletion?(0)
		}
	}

	@discardableResult func writeImage(_ image: ZImage, using originalName: String? = nil) -> URL? {
		if  let name = originalName {
			let url  = assetURL(for: name)

			if  url.writeData(image.jpeg) {
				return url
			}
		}

		// check if file exists at url

		return nil
	}

	func unqiueAssetPath(for file: ZFile) -> String? {
		// if it is already in the Assets folder, grab it, else create it and grab that

		if  let data = file.asset,
			let filename = file.filename {
			let url = assetURL(for: filename)

			if !url.fileExists,
			    url.writeData(data) {
			}

			return url.path
		}

		return nil
	}

    // MARK: - heavy lifting
    // MARK: -

	func writeFile(at path: String, from databaseID: ZDatabaseID?) throws {
		if  gHasFinishedStartup, // guarantee that file read finishes before this code runs
			let     databaseID = databaseID,
			databaseID        != .favoritesID,
			let          cloud = gRemoteStorage.zRecords(for: databaseID) {
			var           dict = ZStorageDictionary ()

			do {
				gRemoteStorage.recount()

				// //////////////////////////////////////////////
				// take snapshots just before exit from method //
				// //////////////////////////////////////////////

				if  let     map  = try cloud.rootZone?.createStorageDictionary(for: databaseID)  {
					dict[.graph] = map as NSObject
				}

				if  let   trash  = try cloud.trashZone?.createStorageDictionary(for: databaseID) {
					dict[.trash] = trash as NSObject
				}

				if  let   destroy  = try cloud.destroyZone?.createStorageDictionary(for: databaseID) {
					dict[.destroy] = destroy as NSObject
				}

				if  let   manifest  = try cloud.manifest?.createStorageDictionary(for: databaseID) {
					dict[.manifest] = manifest as NSObject
				}

				if  let   lost  = try cloud.lostAndFoundZone?.createStorageDictionary(for: databaseID) {
					dict[.lost] = lost as NSObject
				}

				if                 databaseID == .mineID {
					if  let   favorites  = try gFavoritesRoot?.createStorageDictionary(for: .mineID) {
						dict[.favorites] = favorites as NSObject
					}

					if  let   bookmarks  = try gBookmarks.storageArray(for: .mineID) {
						dict[.bookmarks] = bookmarks as NSObject
					}

					if  let      userID  = gUserRecordName {
						dict   [.userID] = userID as NSObject
					}
				}

				FOREBACKGROUND {
					let jsonDict = dict.jsonDict

					if  let data = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted) {
						let  url = URL(fileURLWithPath: path)

						try? data.write(to: url)
					} else {
						printDebug(.dFile, "json error on local storage")
					}
				}
			} catch {
				throw(ZInterruptionError.userInterrupted)
			}
		}
	}

	func readFile(from path: String, into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		if  let    zRecords  = gRemoteStorage.zRecords(for: databaseID),
			let       index  = databaseID.index {
			isReading[index] = true
			typealias  types = [ZStorageType]
			let  keys: types = [.date, .manifest, .graph, .favorites, .bookmarks, .trash, .lost, .destroy]
			if  let     data = gFileManager.contents(atPath: path),
				data  .count > 0,
				let     json = try JSONSerialization.jsonObject(with: data) as? ZStringObjectDictionary {
				let     dict = dictFromJSON(json)

				for key in keys {
					if  let   value = dict[key] {
						let subDict = value as? ZStorageDictionary

						switch key {
							case .date:
								if  let date = value as? Date {
									zRecords.lastSyncDate = date
								}
							case .manifest:
								if  zRecords.manifest == nil, subDict != nil {
									let   manifest  = ZManifest.uniqueManifest(from: subDict!, in: databaseID)
									zRecords.manifest  = manifest
								}
							case .bookmarks:
								if  let array = value as? [ZStorageDictionary] {
									for item in array {
										if  !databaseID.isDeleted(dict: item) {
											let bookmark = Zone.uniqueZone(from: item, in: databaseID)
											if  gBookmarks.addToReverseLookup(bookmark) {
												gRelationships.addBookmarkRelationship(bookmark, target: bookmark.zoneLink?.maybeZone, in: databaseID)
											}
										}
									}
								}
							default:
								if  subDict != nil, !databaseID.isDeleted(dict: subDict!) {
									let check: types = [.favorites, .bookmarks, .destroy, .trash, .lost] // these zones may already be in the CD store
									let         zone = Zone.uniqueZone(from: subDict!, in: databaseID, checkCDStore: check.contains(key))

									zone.updateRecordName(for: key)
									zRecords.registerZRecord(zone)
									zRecords.setRoot(zone, for: key.rootID)
								}
						}
					}
				}
			}

			zRecords.recount()

			isReading[index] = false
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
            let cloudBackupExists = cloudBackupURL.fileExists
            var     genericExists = genericFileURL.fileExists
            let      backupExists =      backupURL.fileExists
            let       cloudExists =   cloudFileURL.fileExists
            path                  = genericFileURL.path

            do {
                if   useGeneric {
                    if !genericExists && (cloudExists || cloudBackupExists) && !isEveryone {
                        if                cloudExists {
                            try gFileManager.moveItem(at: cloudFileURL,   to: genericFileURL)

                            if      cloudBackupExists {
                                try gFileManager.removeItem(at: cloudBackupURL)
                            }

                            genericExists = true
                        } else if   cloudBackupExists {
                            try gFileManager.moveItem(at: cloudBackupURL, to: genericFileURL)
                            
                            genericExists = true
                        }
                    }

                    if     genericExists {
                        if  backupExists {
                            try gFileManager.removeItem(at: backupURL)                       // remove before replacing, below
                        }

                        try gFileManager.copyItem(at: genericFileURL,     to: backupURL)
                    } else if backupExists {
                        try gFileManager.copyItem(at: backupURL,     to: genericFileURL)     // should only happen when prior write fails due to power failure
                    } else if isEveryone,    let bundleFileURL = Bundle.main.url(forResource: "everyone", withExtension: "seriously") {
                        try gFileManager.copyItem(at: bundleFileURL, to: genericFileURL)
                    } else {
						gFileManager.createFile(atPath: genericFileURL.path, contents: nil)
                    }
                } else {
                    path        = cloudFileURL.path

                    if            cloudExists {
                        if  cloudBackupExists {
                            try gFileManager.removeItem(at:  cloudBackupURL)             // remove before replacing, below
                        }

                        try gFileManager.copyItem(at:   cloudFileURL, to: cloudBackupURL)
                    } else if cloudBackupExists {
                        try gFileManager.copyItem(at: cloudBackupURL, to:   cloudFileURL) // should only happen when prior write fails due to power failure
                    } else if    !genericExists {
						gFileManager.createFile(atPath: cloudFileURL.path, contents: nil)
                    } else {
                        try gFileManager.moveItem(at: genericFileURL, to:   cloudFileURL)
                        try gFileManager.copyItem(at:   cloudFileURL, to: cloudBackupURL)
                        
                        genericExists = false
                    }
                    
                    if  backupExists {
                        try gFileManager.removeItem(at:      backupURL)
                    }

                    if  genericExists {
                        try gFileManager.removeItem(at: genericFileURL)
                    }
                }
            } catch {
                printDebug(.dError, "\(error)")
            }

            filePaths[index.rawValue] = path
        }

        return path!
    }

    // MARK: - internals
    // MARK: -

    func createDataDirectory() -> URL {
        do {
            try gFileManager.createDirectory(atPath: gFilesURL.path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            printDebug(.dError, "\(error)")
        }
        
        return gFilesURL
    }

	func createAssetsDirectory() -> URL {
		let url = gFilesURL.appendingPathComponent("assets")

		do {
			try gFileManager.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
		} catch {
			printDebug(.dError, "\(error)")
		}

		return url
	}

    func fileName(for index: ZDatabaseIndex, isGeneric: Bool = true) -> String? {
        if  let databaseID = index.databaseID {
            var name = databaseID.rawValue

            if  databaseID      == .mineID, !isGeneric,
                let userID = gUserRecordName {
                name       = userID
            }

            return name
        }

        return nil
    }

}
