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
	return try! FileManager.default.url(for: .applicationSupportDirectory, in: .allDomainsMask, appropriateFor: nil, create: true)
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

	let               manager = FileManager.default
	var             isReading = [false, false]
    var  filePaths: [String?] = [nil, nil]
	lazy var        assetsURL : URL = { return createAssetsDirectory() }()
	lazy var         filesURL : URL = { return createDataDirectory() }()
	var               hasMine : Bool  { return fileExistsFor(.mineIndex) }
	func assetURL(for fileName: String) -> URL { return assetsURL.appendingPathComponent(fileName) }

	var migrationFilesSize : Int {
		switch gCDMigrationState {
			case .firstTime:       return fileSizeFor(.everyoneID)
			case .migrateFileData: return totalFilesSize
			default:               return 0
		}
	}
	
	lazy var totalFilesSize : Int = {
		var result = 0

		for dbID in kAllDatabaseIDs {
			result += fileSizeFor(dbID)
		}

		return result
	}()

	func fileSizeFor(_ databaseID: ZDatabaseID) -> Int {
		var         result     = 0
		do {
			if  let      index = databaseID.index,
				let    dbIndex = ZDatabaseIndex(rawValue: index) {
				let       path = filePath(for: dbIndex)
				let       dict = try manager.attributesOfItem(atPath: path)
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
			return url.fileExists() || gURL.fileExists()
		}

		return false
	}

	func migrate(into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		if  !hasMine, databaseID == .mineID {
			onCompletion?(0)                   // mine file does not exist, do nothing
		} else {
			try readFile(into: databaseID) { [self] (iResult: Any?) in
				setupFirstTime()

				onCompletion?(iResult)
			}
		}
	}

	func setupFirstTime() {
		gColorfulMode = true
		gStartupLevel = .localOkay
		gDatabaseID   = .everyoneID

		gEveryoneCloud?.rootZone?.expandGrabAndFocusOn()
	}

    func isReading(for iDatabaseID: ZDatabaseID?) -> Bool {
        if  let  dbID = iDatabaseID,
            let index = dbID.index {
            return isReading[index]
        }

        return false
	}

	func writeToFile(from databaseID: ZDatabaseID?) throws {
		if  gWriteFiles,
			gCDMigrationState == .normal,
			let     dbID = databaseID,
			dbID        != .favoritesID,
			let    index = dbID.index,
			let  dbIndex = ZDatabaseIndex(rawValue: index) {
			let path = filePath(for: dbIndex)
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

							} catch {
								printDebug(.dError, "\(error)")
							}
						}
					default: break
				}
			}

			gIsExportingToAFile = false
		}
	}

	func writeImage(_ image: ZImage, using originalName: String? = nil) -> URL? {
		if  let name = originalName {
			let url = assetURL(for: name)

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

			if !url.fileExists(),
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
			let           dbID = databaseID,
			dbID              != .favoritesID,
			let          cloud = gRemoteStorage.zRecords(for: dbID) {
			var           dict = ZStorageDictionary ()

			do {
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

	private func readFile(from path: String, into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		if  let    zRecords  = gRemoteStorage.zRecords(for: databaseID),
			let       index  = databaseID.index {
			isReading[index] = true
			typealias  types = [ZStorageType]
			let  keys: types = [.date, .manifest, .graph, .favorites, .bookmarks, .trash, .lost, .destroy ]

			if  let     data = FileManager.default.contents(atPath: path),
				data  .count > 0,
				let     json = try JSONSerialization.jsonObject(with: data) as? ZStringObjectDictionary {
				let     dict = dictFromJSON(json)

				for key in keys {
					if  let value = dict[key] {

						switch key {
							case .date:
								if  let date = value as? Date {
									zRecords.lastSyncDate = date
								}
							case .manifest:
								if  zRecords.manifest == nil,
									let    subDict  = value as? ZStorageDictionary {
									let   manifest  = ZManifest.uniqueManifest(from: subDict, in: databaseID)
									zRecords.manifest  = manifest
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
            let cloudBackupExists = cloudBackupURL.fileExists()
            var     genericExists = genericFileURL.fileExists()
            let      backupExists =      backupURL.fileExists()
            let       cloudExists =   cloudFileURL.fileExists()
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

    // MARK: - internals
    // MARK: -

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
                let userID = gUserRecordName {
                name       = userID
            }

            return name
        }

        return nil
    }

}
