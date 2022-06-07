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

func gExitSearchMode(force: Bool = true) { if force || gIsSearching { gSearching.exitSearchMode() } }
var  gShowsSearchResults  : Bool { return gSearching.state.isOneOf([.sList]) }

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

class ZSearching: NSObject, ZSearcher {

	var         state = ZSearchState.sNot
	var    hasResults : Bool { return gSearchResultsController?.hasResults ?? false }
	func switchToList()  { setSearchStateTo(.sList) } // hasResults ? .sList : .sNot) }
	func handleEvent(_ event: ZEvent) -> ZEvent? { return gSearchBarController?.handleEvent(event) }

	var essaySearchText: String? {
		get { return gSearchBarController?.searchBox?.text }
		set { gSearchBarController?.searchBox?.text = newValue }
	}

	func exitSearchMode() {
		state = .sNot

		gSignal([.sFound, .sSearch, .spRelayout])

		if  gIsEssayMode {
			assignAsFirstResponder(gEssayView)
		}
	}

	func setSearchStateTo(_ iState: ZSearchState) {
		state = iState

		gControlsController?     .searchStateDidChange()
		gSearchBarController?    .searchStateDidChange()
		gSearchResultsController?.searchStateDidChange()

		if  state == .sFind {
			gSignal([.sSearch])
		}
	}

	func showSearch(_ OPTION: Bool = false) {
//		if  gProducts.hasEnabledSubscription {
		state = .sEntry

		gSignal([OPTION ? .sFound : .sSearch])
//		}
	}

	func performSearch(for searchString: String, closure: Closure?) {
		var combined = ZDBIDRecordsDictionary()

		for cloud in gRemoteStorage.allClouds {
			cloud.foundInSearch = []
			cloud.searchLocal(for: searchString) { [self] in
				let   dbID  = cloud.databaseID
				var results = combined[dbID] ?? ZRecordsArray()

				results.append(contentsOf: cloud.foundInSearch)

				for record in results {
					if  let zone = record as? Zone {
						zone.assureRoot()
					}
				}

				combined[dbID]                             = results
				gSearchResultsController?.foundRecordsDict = combined

				closure?()
				gSearchResultsController?.applyFilter()
				setSearchStateTo(.sList) // hasResults ? .sList : .sEntry)
				gSignal([.sFound])
			}
		}
	}

}
