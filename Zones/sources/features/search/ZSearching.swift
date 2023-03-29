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

func gExitSearchMode(force : Bool = true) { gSearching.exitSearchMode(force: force) }
var  gShowsSearchResults   : Bool  { return gSearching.searchState == .sList }

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

	func exitSearchMode(force : Bool = true) {
		if  force {
			searchState = .sNot       // don't call setSearchStateTo (below), it has unwanted side-effects

			gSearchBarController?.spinner?.stopAnimating()
			gSignal([.sFound, .sSearch, .spRelayout])

			if  gIsEssayMode {
				assignAsFirstResponder(gEssayView)
			}
		}
	}

	func setSearchStateTo(_ iState: ZSearchState) {
		searchState = iState

		gMainController?         .searchStateDidChange()
		gSearchBarController?    .searchStateDidChange()
		gSearchResultsController?.searchStateDidChange()

		gSignal([gSearchStateIsList ? .sFound : .sSearch])
	}

	func performSearch(for searchString: String, closure: Closure?) {
		var combined = ZDBIDRecordsDictionary()
		var    count = gAllClouds.count - 1

		for cloud in gAllClouds {
			cloud.foundInSearch = []
			let      databaseID = cloud.databaseID
			cloud.searchLocal(for: searchString) { [self] in
				var     results = combined[databaseID] ?? ZRecordsArray()
				count          -= 1

				results.append(contentsOf: cloud.foundInSearch)

				combined[databaseID]                       = results
				gSearchResultsController?.foundRecordsDict = combined

				if  let c = gSearchResultsController {
					c.applySearchOptions()
					setSearchStateTo(.sList)
				}

				if  count == 0 {
					closure?() // hide spinner
				}
			}
		}
	}

}
