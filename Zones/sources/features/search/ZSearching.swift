//
//  ZSearching.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/6/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

enum ZSearchState: Int {
    case sEntry
    case sFind
    case sList
    case sNot
    
    func isOneOf(_ states: [ZSearchState]) -> Bool {
        for state in states {
            if self == state {
                return true
            }
        }
        
        return false
    }
}

let gSearching = ZSearching()

class ZSearching: NSObject {

	var state = ZSearchState.sNot
	var priorWorkMode: ZWorkMode?
	var hasResults: Bool { return gSearchResultsController?.hasResults ?? false }
	func switchToList()  { setStateTo(hasResults ? .sList : .sNot) }
	func handleEvent(_ event: ZEvent) -> ZEvent? { return gSearchBarController?.handleEvent(event) }

	var searchText: String? {
		get { return gSearchBarController?.searchBox?.text }
		set { gSearchBarController?.searchBox?.text = newValue }
	}

	func exitSearchMode() {
		state = .sNot

		swapModes()
		gSignal([.sFound, .sSearch])
	}

	func setStateTo(_ iState: ZSearchState) {
		state = iState

		gMainController?         .updateForState()
		gSearchBarController?    .updateForState()
		gSearchResultsController?.updateForState()

		if  state == .sFind {
			gSignal([.sSearch])
		}
	}

	func swapModes() {
		let      last = priorWorkMode ??          .wMapMode
		priorWorkMode = gIsSearchMode ? nil  :    gWorkMode
		gWorkMode     = gIsSearchMode ? last : .wSearchMode
	}

	func showSearch(_ OPTION: Bool = false) {
		swapModes()
		gSignal([OPTION ? .sFound : .sSearch])
	}

	func performSearch(for searchString: String) {
		var remaining = kAllDatabaseIDs.count // same count as allClouds
		var  combined = [ZDatabaseID: [Any]] ()

		let doneMaybe : Closure = {
			if  remaining == 0 {   // done fetching records, transfer them to results controller
				gSearchResultsController?.foundRecords = combined as? [ZDatabaseID: CKRecordsArray] ?? [:]
				self.setStateTo(self.hasResults ? .sList : .sFind)
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
								let trait = cloud.maybeZRecordForCKRecord(record) as? ZTrait ?? ZTrait.create(record: record, databaseID: dbID)

								if  trait.ownerZone == nil {
									orphanedTraits.append(record)   // remove unowned traits from records
								} else {
									trait.register()         // some records are being fetched first time
								}
							}
						}

						for orphan in orphanedTraits {
							if  let index = filtered.firstIndex(of: orphan),
								index     < records.count {
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

}
