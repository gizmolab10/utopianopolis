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
	func switchToList()  { setSearchStateTo(hasResults ? .sList : .sNot) }
	func handleEvent(_ event: ZEvent) -> ZEvent? { return gSearchBarController?.handleEvent(event) }

	var essaySearchText: String? {
		get { return gSearchBarController?.searchBox?.text }
		set { gSearchBarController?.searchBox?.text = newValue }
	}

	func exitSearchMode() {
		state = .sNot

		swapMapAndSearch()
		gSignal([.sFound, .sSearch])
	}

	func setSearchStateTo(_ iState: ZSearchState) {
		state = iState

		gControlsController?     .updateForState()
		gSearchBarController?    .updateForState()
		gSearchResultsController?.updateForState()

		if  state == .sFind {
			gSignal([.sSearch])
		}
	}

	func swapMapAndSearch() {
		let      last = priorWorkMode ??          .wMapMode
		priorWorkMode = gIsSearchMode ? nil  :    gWorkMode
		gWorkMode     = gIsSearchMode ? last : .wSearchMode
	}

	func showSearch(_ OPTION: Bool = false) {
		if  gIsSubscriptionEnabled {
			swapMapAndSearch()
			gSignal([OPTION ? .sFound : .sSearch])
		}
	}

	func performSearch(for searchString: String) {
		if  gIsSearchEssayMode {
			gEssayView?.performSearch(for: searchString)
		} else {
			performGlobalSearch(for: searchString)
		}
	}

	func performGlobalSearch(for searchString: String) {
		var combined = ZRecordsDictionary()

		for cloud in gRemoteStorage.allClouds {
			cloud.foundInSearch.removeAll()
			cloud.searchLocal(for: searchString) {
				let   dbID  = cloud.databaseID
				var results = combined[dbID] ?? ZRecordsArray()

				results.append(contentsOf: cloud.foundInSearch)

				combined[dbID]                         = results
				gSearchResultsController?.foundRecords = combined

				gSearchResultsController?.applyFilter()
				self.setSearchStateTo(self.hasResults ? .sList : .sFind)
				gSignal([.sFound])
			}
		}
	}

}
