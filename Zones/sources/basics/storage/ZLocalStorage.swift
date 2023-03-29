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

extension String {

	func openAsURL() {
#if os(OSX)
		let fileScheme = "file"
		let filePrefix = fileScheme + "://"
		let  urlString = (replacingOccurrences(of: kBackSlash, with: kEmpty).replacingOccurrences(of: kSpace, with: "%20") as NSString).expandingTildeInPath

		if  var url = URL(string: urlString) {
			if  urlString.character(at: 0) == kSlash {
				url = URL(string: filePrefix + urlString)!
			}

			if  url.scheme != fileScheme {
				url.open()
			} else {
				url = URL(fileURLWithPath: url.path)

				url.openAsFile()
			}
		}
#endif
	}

}

extension ZFiles {

	func showInFinder() {
#if os(OSX)
		(filesURL as URL).open()
#endif
	}

	// MARK: - export
	// MARK: -

	func export(_ iZone: Zone?, toFileAs type: ZExportType) {
		guard let zone = iZone else { return }
		let     suffix = type.rawValue
		let       name = zone.zoneName ?? "no name"

		gPresentSavePanel(name: name, suffix: suffix) { fileURL in
			if  let url = fileURL as? URL {
				switch type {
					case .eOutline:
						let string = zone.outlineString()
						do {
							try string.write(to: url, atomically: true, encoding: .utf8)
						} catch {
							printDebug(.dError, "\(error)")
						}

					case .eSeriously:
						do {
							let     dict = try zone.storageDictionary()
							let jsonDict = dict.jsonDict
							let     data = try! JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)

							try data.write(to: url)
						} catch {
							printDebug(.dError, "\(error)")
						}
					case .eEssay:
						if  let text = zone.note?.essayText {
							do {
								let fileData = try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType : NSAttributedString.DocumentType.rtfd])
								let  wrapper = FileWrapper(regularFileWithContents: fileData)

								try  wrapper.write(to: url, options: .atomic, originalContentsURL: nil)

							} catch {
								printDebug(.dError, "\(error)")
							}
						}
					default: break
				}
			}
		}
	}

	func exportDatabase(_ databaseID: ZDatabaseID) {
		gRemoteStorage.updateManifests()
		gPresentSavePanel(name: databaseID.rawValue, suffix: ZExportType.eSeriously.rawValue) { [self] iAny in
			if  let url = iAny as? URL {
				try? writeFile(at: url.relativePath, from: databaseID)
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
		if  flags.exactlyAll {
			gFiles.replaceDatabase(zone.databaseID)
		} else {
			let type : ZExportType = flags.hasOption ? .eOutline : flags.exactlySplayed ? .eCSV : .eSeriously
			
			zone.importFromFile(type) { gRelayoutMaps() }
		}
	}

	func replaceDatabase(_ databaseID: ZDatabaseID) {
		gPresentOpenPanel(type: .eSeriously) { [self] iAny in
			if  let url = iAny as? URL {
				try? readFile(from: url.relativePath, into: databaseID) { _ in
					gFavoritesRoot?.traverseAllProgeny { zone in
						zone       .mapType = .tFavorite
						zone.crossLinkMaybe = nil

//						zone.updateCrossLinkMaybe()
					}

//					FOREGROUND(after: 1.0) {
						gSignal([.spRelayout, .spCrumbs])
//					}
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
			}

			onCompletion?()
		}
	}

}
