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

func gExitSearchMode(force: Bool = true) { if force || gIsSearchMode { gSearching.exitSearchMode() } }
var gShowsSearchResults : Bool { return gSearching.state.isOneOf([.sList]) }

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
		state         = .sNot
		priorWorkMode = gWorkMode
		gWorkMode     = .wMapMode

		gSignal([.sFound, .sSearch, .spRelayout])
	}

	func setSearchStateTo(_ iState: ZSearchState) {
		state = iState

		gControlsController?     .stateDidChange()
		gSearchBarController?    .stateDidChange()
		gSearchResultsController?.stateDidChange()

		if  state == .sFind {
			gSignal([.sSearch])
		}
	}

	func showSearch(_ OPTION: Bool = false) {
//		if  gProducts.hasEnabledSubscription {
			priorWorkMode = nil
			gWorkMode     = .wSearchMode
			gSignal([OPTION ? .sFound : .sSearch])
//		}
	}

	func performSearch(for searchString: String) {
		if  gIsSearchEssayMode {
			gEssayView?.performSearch(for: searchString)
		} else {
			performGlobalSearch(for: searchString)
		}
	}

	func performGlobalSearch(for searchString: String) {
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

				combined[dbID]                         = results
				gSearchResultsController?.foundRecordsDict = combined

				gSearchResultsController?.applyFilter()
				setSearchStateTo(hasResults ? .sList : .sFind)
				gSignal([.sFound])
			}
		}
	}

}
