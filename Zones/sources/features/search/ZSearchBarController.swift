//
//  ZSearchController.swift
//  Seriously
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

var gSearchBarController: ZSearchBarController? { return gControllers.controllerForID(.idSearch) as? ZSearchBarController }

class ZSearchBarController: ZGenericController, ZSearchFieldDelegate {

	@IBOutlet var searchBox            : ZSearchField?
	@IBOutlet var dismissButton        : ZButton?
	@IBOutlet var searchOptionsControl : ZSegmentedControl?
	override  var controllerID         : ZControllerID { return .idSearch }

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        if  iKind == .sSearch && gIsSearchMode {
			gSearching.state = .sEntry

			updateSearchOptions()

			FOREGROUND(after: 0.2) {
                self.searchBox?.becomeFirstResponder()
            }
        }
	}

	func updateSearchOptions() {
		let o = gFilterOption

		searchOptionsControl?.setSelected(o.contains(.fBookmarks), forSegment: 0)
		searchOptionsControl?.setSelected(o.contains(.fNotes),     forSegment: 1)
		searchOptionsControl?.setSelected(o.contains(.fIdeas),     forSegment: 2)
		searchOptionsControl?.action = #selector(searchOptionAction)
		searchOptionsControl?.target = self
	}

	@IBAction func searchOptionAction(sender: ZSegmentedControl) {
		var options = ZFilterOption.fNone

		for index in 0..<sender.segmentCount {
			if  sender.isSelected(forSegment: index) {
				let option = ZFilterOption(rawValue: Int(2.0 ** Double(index)))
				options.insert(option)
			}
		}

		if  options == .fNone {
			options  = .fIdeas
		}

		gFilterOption = options

		if  let text = searchBoxText,
			text.length > 0 {
			performSearch(for: text)
		}
	}

	@IBAction func dismissAction(_ sender: ZButton) {
		endSearch()
	}

	var searchBoxIsFirstResponder : Bool {
		#if os(OSX)
		if  let    first  = searchBox?.window?.firstResponder {
			return first == searchBox?.currentEditor()
		}
		#endif
		
		return false
	}

	func handleArrow(_ arrow: ZArrowKey, with flags: ZEventFlags) {
		#if os(OSX)
		searchBox?.currentEditor()?.handleArrow(arrow, with: flags)
		#endif
	}
	
	func handleEvent(_ event: ZEvent) -> ZEvent? {
        let   string = event.input ?? ""
        let    flags = event.modifierFlags
        let  COMMAND = flags.isCommand
        let      key = string[string.startIndex].description
        let isReturn = key == kReturn
		let    isTab = key == kTab
		let      isF = key == "f"
        let   isExit = kExitKeys.contains(key)
        let    state = gSearching.state
		let  isInBox = searchBoxIsFirstResponder
        let  isEntry = state == .sEntry
        let   isList = state == .sList

		if isList && !isInBox {
			return gSearchResultsController?.handleEvent(event)
		} else if isReturn, isInBox, let text = activeSearchBoxText {
            performSearch(for: text)
        } else if  key == "a" && COMMAND {
            searchBox?.selectAllText()
        } else if (isReturn && isEntry) || (isExit && !isF) || (isF && COMMAND) {
            endSearch()
		} else if isTab {
			assignAsFirstResponder(nil)
		} else if let arrow = key.arrow {
			handleArrow(arrow, with: flags)
		} else {
			if !isReturn, isEntry {
				gSearching.state = .sFind
			}
            
            return event
        }
        
        return nil
    }

    func endSearch() {
        searchBox?.resignFirstResponder()
        gSearching.exitSearchMode()
    }

	var searchBoxText: String? {
		return searchBox?.text?.searchable
	}

    var activeSearchBoxText: String? {
        let searchString = searchBoxText

        if  ["", " ", "  "].contains(searchString) {
            endSearch()

            return nil
        }

		return searchString
    }
    
    func performSearch(for searchString: String) {
		var remaining = kAllDatabaseIDs.count // same count as allClouds
        var  combined = [ZDatabaseID: [Any]] ()
        
        let doneMaybe : Closure = {
            if  remaining == 0 {
                gSearchResultsController?.foundRecords = combined as? [ZDatabaseID: CKRecordsArray] ?? [:]
				gSearching.state = (gSearchResultsController?.hasResults ?? false) ? .sList : .sFind
                
                gSignal([.sFound])
            }
        }
        
        for cloud in gRemoteStorage.allClouds {
            let locals = cloud.searchLocal(for: searchString)
			let   dbID = cloud.databaseID

            if  gUser == nil || !gHasInternet {
                combined[dbID] = locals
                remaining -= 1

                doneMaybe()
            } else {
                cloud.search(for: searchString) { iObject in
                    FOREGROUND {
						remaining   -= 1
						var orphanedTraits = CKRecordsArray()
						var records        = iObject as! CKRecordsArray
						var filtered       = records.filter { record -> Bool in
							return record.matchesFilterOptions
						}

						for record in filtered {
							if  record.recordType == kTraitType {
								let trait = cloud.maybeZRecordForCKRecord(record) as? ZTrait ?? ZTrait(record: record, databaseID: dbID)

								if  trait.ownerZone == nil {
									orphanedTraits.append(record)   // remove unowned traits from records
								} else {
									trait.register()         // some records are being fetched first time
								}
							}
						}

						for orphan in orphanedTraits {
							if  let index = filtered.firstIndex(of: orphan) {
								records.remove(at: index)
							}
						}

						filtered.appendUnique(contentsOf: locals) { (a, b) in
                            if  let alpha = a as? CKRecord,
                                let  beta = b as? CKRecord {
                                return alpha.recordID.recordName == beta.recordID.recordName
                            }
                            
                            return false
                        }
                        
                        combined[dbID] = filtered
                        
                        doneMaybe()
                    }
                }
            }
        }
    }
    
    func control(_ control: ZControl, textView: ZTextView, doCommandBy commandSelector: Selector) -> Bool {
        let handledIt = commandSelector == Selector(("noop:"))

        if  handledIt {
            endSearch()
        }

        return handledIt
    }

}
