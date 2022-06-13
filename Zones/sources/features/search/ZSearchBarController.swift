//
//  ZSearchController.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/15/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

protocol ZSearcher {
	func performSearch(for searchString: String, closure: Closure?)
}

var gSearchBarController: ZSearchBarController? { return gControllers.controllerForID(.idSearch) as? ZSearchBarController }

class ZSearchBarController: ZGenericController, ZSearchFieldDelegate {

	@IBOutlet var    searchBox : ZSearchField?
	@IBOutlet var      spinner : ZProgressIndicator?
	override  var controllerID : ZControllerID { return .idSearch }
	var    activeSearchBoxText : String?       { return searchBox?.text?.searchable }

	override func awakeFromNib() {
		super.awakeFromNib()

		spinner?.zlayer.backgroundColor = gBackgroundColor.cgColor
	}

	var searchBoxIsFirstResponder : Bool {
		#if os(OSX)
		if  let    first  = searchBox?.window?.firstResponder {
			return first == searchBox?.currentEditor()
		}
		#endif

		return false
	}

	func searchStateDidChange() {
		switch gSearching.state {
			case .sEntry, .sFind:
				assignAsFirstResponder(searchBox)
			default: break
		}
	}

	// MARK: - events
	// MARK: -

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		if  gIsSearching, !gWaitingForSearchEntry {
			gSearching.setSearchStateTo(.sEntry)
		}
	}

	func handleArrow(_ arrow: ZArrowKey, with flags: ZEventFlags) {
		#if os(OSX)
		if  searchBoxIsFirstResponder {
			searchBox?.currentEditor()?.handleArrow(arrow, with: flags)
		} else if gIsResultsMode {
		} else if gIsEssayMode {
			gEssayView?.handleArrow(arrow, flags: flags)
		}
		#endif
	}

	func handleEvent(_ event: ZEvent) -> ZEvent? {
		let    string = event.input ?? kEmpty
		let     flags = event.modifierFlags
		let   COMMAND = flags.isCommand
		let       key = string[string.startIndex].description
		let       isF = key == "f"
		let     isTab = key == kTab
		let  isReturn = key == kReturn
		let  isEscape = key == kEscape
		let    isList = gSearchResultsVisible
		let   isEntry = gWaitingForSearchEntry
		let   isInBox = searchBoxIsFirstResponder

		if (gIsEssayMode && !isInBox) || (key == "g" && COMMAND) {
			gEssayView?.handleKey(key, flags: flags)
		} else if isList, !isInBox {
			if !isF {
				return gSearchResultsController?.handleEvent(event)
			}

			gSearching.setSearchStateTo(.sEntry)
		} else if isReturn, isInBox {
			updateSearchBox()
		} else if COMMAND, key == "a" {
            searchBox?.selectAllText()
        } else if isEscape || (isReturn && isEntry) || (COMMAND && isF) {
            endSearch()
		} else if isTab {
			gSearching.switchToList()
		} else if let arrow = key.arrow {
			handleArrow(arrow, with: flags)
		} else {
			if !isReturn, isEntry {
				gSearching.state = .sFind // don't call setSearchStateTo, it has unwanted side-effects
			}
            
            return event
        }

        return nil
    }

    func endSearch() {
        searchBox?.resignFirstResponder()
		gExitSearchMode()
    }

	func updateSearchBox(allowSearchToEnd: Bool = true) {
		if  let text = activeSearchBoxText,
			text.length > 0,
			![kEmpty, kSpace, "  "].contains(text) {

			if  let searcher: ZSearcher = gIsEssayMode ? gEssayView : gSearching {
				spinner?.startAnimating()
				searcher.performSearch(for: text) {
					self.spinner?.stopAnimating()
				}
			}

		} else if allowSearchToEnd {
			endSearch()
		}
	}

}
