//
//  ZLocalStorage.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/17/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

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

	func export(_ zone: Zone, toFileAs type: ZExportType) {
		let           panel = NSSavePanel()
		let          suffix = type.rawValue
		panel      .message = "Export as \(suffix)"
		gIsExportingToAFile = true
		if  let        name = zone.zoneName {
			panel.nameFieldStringValue = "\(name).\(suffix)"
		}

		panel.begin { result in
			if  result == .OK,
				let fileURL = panel.url {

				BACKGROUND {
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

					gIsExportingToAFile = false
				}
			}
		}
	}

	// MARK: - import
	// MARK: -

	static func presentOpenPanel(_ callback: AnyClosure? = nil) {
#if os(OSX)
		if  let  window = gApplication?.mainWindow {
			let   panel = NSOpenPanel()

			callback?(panel)

			panel.resolvesAliases               = true
			panel.canChooseDirectories          = false
			panel.canResolveUbiquitousConflicts = false
			panel.canDownloadUbiquitousContents = false

			panel.beginSheetModal(for: window) { (result) in
				if  result == NSApplication.ModalResponse.OK,
					panel.urls.count > 0 {
					let url = panel.urls[0]

					callback?(url)
				}
			}
		}
#endif
	}

}

extension Zone {

	func importFromFile(_ type: ZExportType, onCompletion: Closure?) {
		ZFiles.presentOpenPanel() { [self] (iAny) in
			if  let url = iAny as? URL {
				importFile(from: url.path, type: type, onCompletion: onCompletion)
			} else if let panel = iAny as? NSOpenPanel {
				let  suffix = type.rawValue
				panel.title = "Import as \(suffix)"
				panel.allowedFileTypes = [suffix]
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
		if  let data = FileManager.default.contents(atPath: path),
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
