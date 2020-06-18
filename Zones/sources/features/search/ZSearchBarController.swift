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


    @IBOutlet var searchBox: ZSearchField?
	override  var controllerID: ZControllerID { return .idSearch }


    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        if  iKind == .sSearch && gIsSearchMode {
			gSearching.state = .sEntry

            FOREGROUND(after: 0.2) {
                self.searchBox?.becomeFirstResponder()
            }
        }
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
		} else if isReturn, isInBox, let text = searchBoxText {
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
        let searchString = (searchBox?.text)!

        if ["", " ", "  "].contains(searchString) {
            endSearch()

            return nil
        }

		return searchString.searchable
    }

    
    func performSearch(for searchString: String) {
        var combined = [ZDatabaseID: [Any]] ()
        var remaining = kAllDatabaseIDs.count
        
        let done : Closure = {
            if  remaining == 0 {
                gSearchResultsController?.foundRecords = combined as? [ZDatabaseID: [CKRecord]] ?? [:]
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

                done()
            } else {
                cloud.search(for: searchString) { iObject in
                    FOREGROUND {
                        var results = iObject as! [CKRecord]
						var orphans = [CKRecord]()
                        remaining  -= 1

						for record in results {
							if  let trait = cloud.maybeZRecordForCKRecord(record) as? ZTrait {
								if  trait.ownerZone == nil {
									orphans.append(record)       // remove unowned traits from results
								}
							} else if cloud.maybeZoneForCKRecord(record) == nil {
								let trait = ZTrait(record: record, databaseID: dbID)

								if  trait.ownerZone != nil {
									cloud.registerZRecord(trait) // some records are being fetched first time
								} else {
									orphans.append(record)       // remove unowned traits from results
								}
							}
						}

						for orphan in orphans {
							if let index = results.firstIndex(of: orphan) {
								results.remove(at: index)
							}
						}

                        results.appendUnique(contentsOf: locals) { (a, b) in
                            if  let alpha = a as? CKRecord,
                                let  beta = b as? CKRecord {
                                return alpha.recordID.recordName == beta.recordID.recordName
                            }
                            
                            return false
                        }
                        
                        combined[dbID] = results
                        
                        done()
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
