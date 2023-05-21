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
		let finish = { [self] in
			setSearchStateTo(.sList)
			closure?() // hide spinner
		}

		guard let controller = gSearchResultsController else {
			finish()

			return
		}

		var         search  : Closure?
		var       combined  = ZDBIDRecordsDictionary()
		var          index  = 0
		search              = {
			if       index == gAllClouds.count {
				controller.applySearchOptions()
				finish()

				return
			}

			let       cloud = gAllClouds[index]
			let  databaseID = cloud.databaseID

			cloud.searchLocal(for: searchString) { zRecords in
				index      += 1
				var results = combined[databaseID] ?? ZRecordsArray()

				results.append(contentsOf: zRecords)

				combined[databaseID]                       = results
				gSearchResultsController?.foundRecordsDict = combined

				search?()
			}
		}

		search?()
	}

}
