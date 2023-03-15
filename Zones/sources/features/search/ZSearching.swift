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
var  gShowsSearchResults  : Bool { return gSearching.searchState == .sList }

enum ZSearchState: Int {
    case sEntry
    case sFind
    case sList
    case sNot
}

let gSearching = ZSearching()

class ZSearching: NSObject, ZSearcher {

	var searchState = ZSearchState.sNot
	var  hasResults : Bool                       { return gSearchResultsController?.hasResults ?? false }
	func handleEvent(_ event: ZEvent) -> ZEvent? { return gSearchBarController?.handleEvent(event) }

	var essaySearchText: String? {
		get { return gSearchBarController?.searchBar?.text }
		set { gSearchBarController?.searchBar?.text = newValue }
	}

	func exitSearchMode() {
		searchState = .sNot // don't call setSearchStateTo (below), it has unwanted side-effects

		gSignal([.sFound, .sSearch, .spRelayout])

		if  gIsEssayMode {
			assignAsFirstResponder(gEssayView)
		}
	}

	func setSearchStateTo(_ iState: ZSearchState) {
		searchState = iState

		gMainController?         .searchStateDidChange()
		gSearchBarController?    .searchStateDidChange()
		gSearchResultsController?.searchStateDidChange()

		switch searchState {
			case .sList:          gSignal([.sFound])
			case .sFind, .sEntry: assignAsFirstResponder(gIsNotSearching ? nil : gSearchBarController?.searchBar)

			default: break
		}
	}

	func performSearch(for searchString: String, closure: Closure?) {
		var combined = ZDBIDRecordsDictionary()

		for cloud in gRemoteStorage.allClouds {
			cloud.foundInSearch = []
			cloud.searchLocal(for: searchString) { [self] in
				let   databaseID  = cloud.databaseID
				var results = combined[databaseID] ?? ZRecordsArray()

				for record in cloud.foundInSearch {
					if  let zone = record as? Zone {
						zone.assureRoot()
					}
				}

				results.append(contentsOf: cloud.foundInSearch)

				combined[databaseID]                             = results
				gSearchResultsController?.foundRecordsDict = combined

				if  let c = gSearchResultsController {
					c.applyFilter()
					setSearchStateTo(.sList)
				}

				closure?() // hide spinner
			}
		}
	}

}
