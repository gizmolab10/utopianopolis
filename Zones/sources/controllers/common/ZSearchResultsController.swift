//
//  ZSearchResultsController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 12/15/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


var gSearchResultsController: ZSearchResultsController? { return gControllers.controllerForID(.idSearchResults) as? ZSearchResultsController }


class ZSearchResultsController: ZGenericController, ZTableViewDataSource, ZTableViewDelegate {


    var      resultsAreVisible = false
    var           foundRecords = [ZDatabaseID: [CKRecord]] ()
	var     searchText: String?  { return gSearchController?.searchBox?.text }
	override  var controllerID:  ZControllerID { return .idSearchResults }
    @IBOutlet var    tableView:  ZTableView?

    
    var hasResults: Bool {
        var     result = false

        for     results in foundRecords.values {
            if  results.count > 0 {
                result = true
                
                break
            }
        }
        
        return result
    }


    var foundRecordsCount: Int {
        var count = 0

        for records in foundRecords.values {
            count += records.count
        }

        return count
    }


    // MARK:- content
    // MARK:-


    func sortRecords() {
        for (mode, records) in foundRecords {
            foundRecords[mode] = records.sorted() {
                if  let a = $0[kpZoneName] as? String,
                    let b = $1[kpZoneName] as? String {
                    return a.lowercased() < b.lowercased()
                }

                return false
            }
        }
    }


    // MARK:- delegate
    // MARK:-


    #if os(OSX)

    func numberOfRows(in tableView: ZTableView) -> Int { return foundRecordsCount }


    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if  let (dbID, record) = identifierAndRecord(at: row) {
			var string = ""
			
            if  let zone = gRemoteStorage.cloud(for: dbID)?.maybeZoneForRecordID(record.recordID) {
                string =   zone.decoratedName
            } else {
                string = record.decoratedName
            }

			if  let   text = searchText,
				let ranges = string.rangesMatching(text) {				// find all matching substring ranges
				var result = NSMutableAttributedString(string: string)

				for range in ranges {
					result.addAttribute(.backgroundColor, value: NSColor.systemYellow, range: range) // highlight matching substring in yellow
				}

				if  row == tableView.selectedRow {
					let suffix = result
					result     = NSMutableAttributedString(string: "• ")

					result.append(suffix)
				}

				return result
			}
        }
		
		return nil
    }

    #else


    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int            { return foundRecordsCount }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell { return UITableViewCell() }


    #endif


    // MARK:- user feel
    // MARK:-
	
	
	func switchToSearchBox() { gSearchController?.searchBox?.becomeFirstResponder() }


    func identifierAndRecord(at iIndex: Int) -> (ZDatabaseID, CKRecord)? {
        var index = iIndex
        var count = 0

        for (mode, records) in foundRecords {
            index -= count
            count  = records.count

            if count > index {
                return (mode, records[index])
            }
        }

        return nil
    }


    @discardableResult func resolve() -> Bool {
        var resolved = false

        #if os(OSX)
            if  gIsSearchMode,
                let          index = self.tableView?.selectedRow,
                index             != -1,
                let (dbID, record) = identifierAndRecord(at: index) {
                resolved           = true

                resolveRecord(dbID, record)
            }
        #endif

        return resolved
	}

	func resolveRecord(_ dbID: ZDatabaseID, _ record: CKRecord) {
		gDatabaseID = dbID

		clear()

		if !resolveAsTrait(     record) {
			resolveAsZone(dbID, record)
		}
    }

	func resolveAsTrait(_ record: CKRecord) -> Bool {
		guard let  trait = gCloud?.maybeTraitForRecordID(record.recordID),
			let recordID = trait.owner?.recordID,
			let     zone = gCloud?.maybeZoneForRecordID(recordID) else {
			return false
		}

		gEssayView?.resetCurrentEssay(zone.note)
		gControllers.swapGraphAndEssay(force: .noteMode)
		signalRegarding(.eSwap)

		return true
	}

    func resolveAsZone(_ dbID: ZDatabaseID, _ record: CKRecord) {
        var zone  = gCloud?.maybeZoneForRecordID(record.recordID)

        if  zone == nil {
            zone  = Zone(record: record, databaseID: dbID)
        }

        gHere     = zone!

		zone?.needChildren()
		zone?.revealChildren()
		redrawGraph()

		zone?.editAndSelect(text: searchText)

        gControllers.sync()
    }


    func clear() {
        resultsAreVisible = false
        
        if  gIsSearchMode {
            gSetGraphMode()

            signalRegarding(.eSearch)
            signalRegarding(.eFound)
        }
    }


    func reset() {
        if  resultsAreVisible || foundRecords.count == 0 {
            clear()
        } else {
            resultsAreVisible = true

            signalRegarding(.eSearch)
        }
    }


    func moveSelection(up: Bool, extreme: Bool) {
        if  let             t = tableView {
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

            let rows = [row] as IndexSet

            t.selectRowIndexes(rows, byExtendingSelection: false)
            t.scrollRowToVisible(row)
        }
    }
	

	// MARK:- events
	// MARK:-


	override func handleSignal(_ iObject: Any?, kind iKind: ZSignalKind) {
		if iKind == .eFound {
			resultsAreVisible = false
			
			if  gIsSearchMode, foundRecords.count > 0 {
				var dbID: ZDatabaseID?
				var record: CKRecord?
				var total = 0
				
				for (databaseID, records) in foundRecords {
					let count  = records.count
					total     += count
					
					if  count == 1 {
						record = records[0]
						dbID   = databaseID
					}
				}
				
				if total == 1 {
					self.resolveRecord(dbID!, record!) // not bother user if only one record found
				} else if total > 0 {
					sortRecords()
					tableView?.reloadData()
					
					#if os(OSX)
					FOREGROUND {
						self.assignAsFirstResponder(nil)
						self.tableView?.selectRowIndexes(IndexSet([0]), byExtendingSelection: false)
					}
					#endif
				}
			}
		}
	}
	

    func handleEvent(_ event: ZEvent) -> ZEvent? {
        if  let       string = event.input {
            let        flags = event.modifierFlags
            let      COMMAND = flags.isCommand
            let          key = string[string.startIndex].description        // N.B. test key first since getInput has a possible side-effect of exiting search
            
            if  let    arrow = key.arrow {
                switch arrow {
					case       .up: moveSelection(up: true,  extreme: COMMAND)
					case     .down: moveSelection(up: false, extreme: COMMAND)
					case    .right: if !resolve() { return event }
					case     .left: switchToSearchBox()
                }
            } else {
                switch key {
					case "f", kTab: switchToSearchBox()
					case   kReturn: if !resolve() { return event }
					case   kEscape: clear()
					default: return event
                }
            }
        }
        
        return nil
    }

}
