//
//  ZSearchResultsController.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/15/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

var gSearchResultsController: ZSearchResultsController? { return gControllers.controllerForID(.idSearchResults) as? ZSearchResultsController }

class ZSearchResultsController: ZGenericTableController {

	var   filteredResultsDict = ZDBIDRecordsDictionary()
	var      foundRecordsDict = ZDBIDRecordsDictionary()
	var            searchText : String?       { return gSearchBarController?.activeSearchBoxText }
	override var controllerID : ZControllerID { return .idSearchResults }
	func         zoneAt(_ row : Int) -> Zone? { return zoneFor(zRecordAt(row)) }
	func              clear()                 { gExitSearchMode(force: false) }

	func applyFilter() {
		filteredResultsDict = ZDBIDRecordsDictionary()

		for (dbID, records) in foundRecordsDict {
			var matches = ZRecordsArray()

			for record in records {
				if  record.matchesFilterOptions {
					matches.append(record)
				}
			}

			filteredResultsDict[dbID] = matches
		}
	}

    var hasResults: Bool {
        var     result = false
        for     results in filteredResultsDict.values {
            if  results.count > 0 {
                result = true
                
                break
            }
        }
        
        return result
    }

	var selectedResult: Zone? {
		if  let row = genericTableView?.selectedRow {
			return zoneAt(row)
		}

		return nil
	}

    var filteredResultsCount: Int {
        var count = 0

        for records in filteredResultsDict.values {
            count += records.count
        }

        return count
    }

    // MARK: - content
    // MARK: -

    func sortRecords() {
        for (dbID, records) in filteredResultsDict {
			filteredResultsDict[dbID] = records.sorted() {
				if  let a = ($0 as? Zone)?.zoneName,
                    let b = ($1 as? Zone)?.zoneName {
                    return a.lowercased() < b.lowercased()
                }

                return false
            }
        }
    }

	func zRecordAt(_ row: Int) -> ZRecord? {
		if  let (_, zRecord) = identifierAndRecord(at: row) {
			return zRecord
		}

		return nil
	}

	func zoneFor(_ zRecord: ZRecord?) -> Zone? {
		var      zone = zRecord as? Zone
		if  let trait = zRecord as? ZTrait {
			zone      = trait.ownerZone
		}

		return zone
	}

    // MARK: - delegate
    // MARK: -

    #if os(OSX)

    override func numberOfRows(in tableView: ZTableView) -> Int { return filteredResultsCount }

	func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		let    zRecord = zRecordAt(row)
		var     string = kEmpty
		var     prefix = NSMutableAttributedString()
		var       size = 0
		if  let      z = zRecord {
			string     = z.decoratedName
			var      p = z.typePrefix
			size       = p.length
			if    size > 0 {
				let  r = NSRange(location: 0, length: size)
				p.append(kSpace)
				prefix = NSMutableAttributedString(string: p)
				size  += 1

				prefix.addAttribute(.backgroundColor, value: ZColor.systemYellow, range: r)
			}
		}

		var result = prefix

		result.append(NSMutableAttributedString(string: string))

		if  let searched = searchText {
			for text in searched.components(separatedBy: kSpace) {
				if  let ranges = string.rangesMatching(text) {				      // find all matching substring ranges
					for range in ranges {
						let r = range.offsetBy(size)
						result.addAttribute(.backgroundColor, value: NSColor.systemTeal, range: r) // highlight matching substring in teal
					}
				}
			}
		}

		if  row == tableView.selectedRow {
			let suffix = result
			result     = NSMutableAttributedString(string: "• ")

			result.append(suffix)
		}

		return result
	}

    #else

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int            { return filteredResultsCount }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell { return UITableViewCell() }

    #endif

    // MARK: - user feel
    // MARK: -

    func identifierAndRecord(at iRow: Int) -> (ZDatabaseID, ZRecord)? {
        var   row = iRow
        var count = 0

        for (dbID, records) in filteredResultsDict {
            row   -= count
            count  = records.count

            if  row >= 0, row < count,
				let record = records[row].selfInCurrentBackgroundCDContext {
                return (dbID, record)
            }
        }

        return nil
    }

    @discardableResult func resolve() -> Bool {
        var resolved = false

        #if os(OSX)
            if  gIsSearchMode,
                let            row = genericTableView?.selectedRow,
                row               != -1,
                let (dbID, record) = identifierAndRecord(at: row) {
                resolved           = true
				resolveRecord(dbID, record)
            }
        #endif

        return resolved
	}

	@discardableResult func resolveRecord(_ dbID: ZDatabaseID, _ zRecord: ZRecord) -> Bool {
		gDatabaseID = dbID

		clear()

		return resolveAsTrait(dbID, zRecord)
			|| resolveAsZone (dbID, zRecord)
	}

	func resolveAsZone(_ dbID: ZDatabaseID, _ zRecord: ZRecord) -> Bool {
		let zone = zRecord as? Zone

		zone?.resolveAsHere()

		return zone != nil
	}

	func resolveAsTrait(_ dbID: ZDatabaseID, _ zRecord: ZRecord) -> Bool {
		guard let trait = zRecord as? ZTrait,
			let   owner = trait.ownerZone,
			let    type = trait.traitType else {
			return false
		}

		switch type {
			case .tEssay,
				 .tNote: resolveAsNote(owner)
			default:     owner.resolveAsHere()    // hyperlink or email
		}

		return true
	}

	func resolveAsNote(_ zone: Zone) {
		if  let   note = zone.note {
			let ranges = note.noteText?.string.rangesMatching(searchText)
			let range  = ranges == nil ? nil : ranges![0]

			gControllers.swapMapAndEssay(force: .wEssayMode)
			gEssayView?.resetCurrentEssay(note, selecting: range)
		}
	}

	func stateDidChange() {
		if  gSearchResultsVisible {
			genericTableView?.becomeFirstResponder()
		}
	}

    func reset() {
        if  gSearchResultsVisible || filteredResultsDict.count == 0 {
            clear()
        } else {
            gSignal([.sSearch])
        }
    }

	func removeRecord(at row: Int) -> Bool {
		if  let            (dbID, record) = identifierAndRecord(at: row) {
			var                   records = filteredResultsDict[dbID]
			if  let                 index = records?.firstIndex(of: record) {
				records?.remove(at: index)
				filteredResultsDict[dbID] = records

				if  let              zone = zoneFor(record) {
					zone.deleteSelf {}
				}

				return true
			}
		}

		return false
	}

	func removeSelection() {
		if  let   t = genericTableView {
			let row = t.selectedRow

			if  removeRecord(at: row) {
				t.reloadData()
				selectAndRedisplay(row: row)
			}
		}
	}

	func selectAndRedisplay(row: Int) {
		if  let    t = genericTableView {
			let rows = [row] as IndexSet

			t.selectRowIndexes(rows, byExtendingSelection: false)
			t.scrollRowToVisible(row)
			gSignal([.spCrumbs])
		}
	}

	func moveSelection(up: Bool, extreme: Bool) {
		if  let             t = genericTableView {
			var           row = t.selectedRow
			let       maximum = t.numberOfRows - 1

			if extreme {
				row           = up ?  0 : maximum
			} else {
				row          += up ? -1 : 1

				if  row       > maximum {
					row       = 0
				} else if row < 0 {
					row       = maximum
				}
			}

			selectAndRedisplay(row: row)
		}
	}

	// MARK: - events
	// MARK: -

	func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
		gSearching.setSearchStateTo(.sList)
		tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
		gSignal([.spCrumbs])
		return true
	}

	override func handleSignal(_ iObject: Any?, kind: ZSignalKind) {
		if  let t = genericTableView {
			t.tableColumns[0].width = t.frame.width
		}

		if  gIsSearchMode, filteredResultsDict.count > 0 {
			var dbID: ZDatabaseID?
			var zRecord: ZRecord?
			var total = 0

			for (databaseID, records) in filteredResultsDict {
				let count  = records.count
				total     += count

				if  count == 1 {
					zRecord = records[0]
					dbID   = databaseID
				}
			}

			if  total == 1 {               // not bother user if only one record found
				resolveRecord(dbID!, zRecord!)
			} else if total > 0 {
				sortRecords()
				genericTableUpdate()

				#if os(OSX)
				FOREGROUND { [self] in
					assignAsFirstResponder(nil)
					genericTableView?.selectRowIndexes(IndexSet([0]), byExtendingSelection: false)
				}
				#endif
			}
		}
	}

    func handleEvent(_ event: ZEvent) -> ZEvent? {
        if  let string = event.input {
            let  flags = event.modifierFlags
            let    key = string[string.startIndex].description        // N.B. test key first since getInput has a possible side-effect of exiting search

			if !handleKey(key, flags: flags) { return event }
        }
        
        return nil
	}

	@discardableResult func handleKey(_ key: String, flags: ZEventFlags) -> Bool { // false means not handled
		switch key {
			case "f", kTab: gSearching.setSearchStateTo(.sFind)
			case kReturn: if !resolve() { return false }
			case kEscape: clear()
			case kDelete: removeSelection()
			default:
				if  let arrow = key.arrow,
					!handleArrow(arrow, flags: flags) {
					return false
			}
		}

		return true
	}

	@discardableResult func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) -> Bool { // false means not handled
		let COMMAND = flags.isCommand

		switch arrow {
			case .up, .down: moveSelection(up: arrow == .up, extreme: COMMAND)
			case     .right: if !resolve() { return false }
			case      .left: gSearching.setSearchStateTo(.sFind)
		}

		return true
	}

}
