//
//  ZLocalStorage.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/17/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation
import CoreFoundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

extension ZFiles {

	func showInFinder() {
		#if os(OSX)
		(filesURL as URL).open()
		#endif
	}

	// MARK: - export
	// MARK: -

	func export(_ iZone: Zone?, toFileAs type: ZExportType) {
		guard let  zone = iZone else { return }
		let      suffix = type.rawValue
		let        name = zone.zoneName ?? "no name"

		gPresentSavePanel(name: name, suffix: suffix) { iURL in
			if  let url = iURL {
				do {
					switch type {
						case .eOutline:
							let string = zone.outlineString()

							try string.write(to: url, atomically: true, encoding: .utf8)
						case .eSeriously:
							let     dict = try zone.storageDictionary()
							let jsonDict = dict.jsonDict
							let     data = try! JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)

							try data.write(to: url)
						case .eEssay:
							if  let     text = zone.note?.essayText {
								let fileData = try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType : NSAttributedString.DocumentType.rtfd])
								let  wrapper = FileWrapper(regularFileWithContents: fileData)

								try  wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
							}
						default: break
					}
				} catch {
					printDebug(.dError, "\(error)")
				}
			}
		}
	}

	func exportDatabase(_ databaseID: ZDatabaseID) {

		//		gRemoteStorage.updateManifests()             // INSANE! this aborts the current runloop!!!

		gPresentSavePanel(name: databaseID.rawValue, suffix: ZExportType.eSeriously.rawValue) { [self] iURL in
			if  let path = iURL?.relativePath {
				try? self.writeFile(at: path, from: databaseID)
			}
		}
	}

	func exportFromZone(_ zone: Zone, with flags: ZEventFlags) {
		if  flags.exactlyAll {
			exportDatabase(zone.databaseID)
		} else {
			let          exporting = flags.hasCommand ? gRecords.rootZone : zone
			let type : ZExportType = flags.hasOption  ? .eOutline : .eSeriously

			export(exporting, toFileAs: type)
		}
	}

	// MARK: - import
	// MARK: -

	func importToZone(_ zone: Zone, with flags: ZEventFlags) {
		let type : ZExportType = flags.hasOption ? .eOutline : flags.exactlySplayed ? .eCSV : .eSeriously

		zone.importFromFile(type) {
			gRelayoutMaps()
		}
	}

	func replaceDatabase(_ databaseID: ZDatabaseID?, onCompletion: Closure?) {
		if  let            id = databaseID {
			let          dbid = id.identifier
			gPresentOpenPanel(type: .eSeriously) { [self] iAny in
				if  let   url = iAny as? URL,
					let cloud = gRemoteStorage.cloud(for: id),
					let  root = cloud.rootZone {

					let closure: Closure = { [self] in
						try? readFile(from: url.relativePath, into: id) { _ in

							// minor corrections needed for favorites font size and updating bookmark names

							if  let                root = gFavoritesRoot {
								root.traverseAllProgeny { zone in
									zone       .mapType = .tFavorite
									zone.crossLinkMaybe = nil
								}
							}

							if  let           cloudRoot = cloud.rootZone {
								gHere                   = cloudRoot

								cloudRoot.updateZoneNamesForBookmkarksTargetingSelf()
							}

							cloud.applyToAllZones { zone in
								zone.dbid = dbid
							}

							onCompletion?()
						}
					}

					// first delete potentially duplicated zones (root and children of recents)

					root.deleteSelf(permanently: true, force: true) { _ in
						if  let zones = gFavorites.recentsMaybe?.children {
							zones.deleteZones(permanently: true, onCompletion: closure)
						} else {
							closure()
						}
					}
				}
			}
		}
	}

}

extension Zone {

	func importFromFile(_ type: ZExportType, onCompletion: Closure?) {
		gPresentOpenPanel(type: type) { [self] iAny in
			if  let url = iAny as? URL {
				importFile(from: url.path, type: type, onCompletion: onCompletion)
			}
		}
	}

	func importSeriously(from data: Data) -> Zone? {
		var zone: Zone?
		if  let json = data.extractJSONDict() {
			let dict = dictFromJSON(json)
			temporarilyOverrideIgnore { // allow needs save
				zone = Zone.uniqueZone(from: dict, in: databaseID)
			}
		}

		return zone
	}

	func importCSV(from data: Data, kumuFlavor: Bool = false) {
		let   rows = data.extractCSV()
		var titles = [String : Int]()
		let  first = rows[0]
		for (index, title) in first.enumerated() {
			titles[title] = index
		}

		for (index, row) in rows.enumerated() {
			if  index     != 0,
				let nIndex = titles["Name"],
				let tIndex = titles["Type"],
				row.count  > tIndex {
				let   name = row[nIndex]
				let   type = row[tIndex]
				let  child =       childWithName(type)
				let gChild = child.childWithName(name)

				if  let      dIndex = titles["Description"] {
					let       trait = ZTrait.uniqueTrait(recordName: nil, in: databaseID)
					let        text = row[dIndex]
					trait     .text = text
					trait.traitType = .tNote

					gChild.addTrait(trait)
				}
			}
		}
	}

	func importFile(from path: String, type: ZExportType = .eSeriously, onCompletion: Closure?) {
		if  let data = gFileManager.contents(atPath: path),
			data.count > 0 {
			var zone: Zone?

			switch type {
				case .eSeriously: zone = importSeriously(from: data)
				default:                 importCSV      (from: data, kumuFlavor: true)
			}

			if  let z = zone {
				addChildNoDuplicate(z, at: 0)
				respectOrder()
			}

			onCompletion?()
		}
	}

}
