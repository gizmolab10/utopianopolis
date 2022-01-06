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

var gSearchBarController: ZSearchBarController? { return gControllers.controllerForID(.idSearch) as? ZSearchBarController }

class ZSearchBarController: ZGenericController, ZSearchFieldDelegate {

	@IBOutlet var    searchBox : ZSearchField?
	override  var controllerID : ZControllerID { return .idSearch }
	var    activeSearchBoxText : String?       { return searchBox?.text?.searchable }

	var searchBoxIsFirstResponder : Bool {
		#if os(OSX)
		if  let    first  = searchBox?.window?.firstResponder {
			return first == searchBox?.currentEditor()
		}
		#endif

		return false
	}

	func updateForState() {
		switch gSearching.state {
			case .sList:
				searchBox?.isHidden = true
			case .sEntry, .sFind:
				searchBox?.isHidden = false
				searchBox?.becomeFirstResponder()
			default: break
		}
	}

	// MARK: - events
	// MARK: -

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		if  gIsSearchMode {
			gSearching.setSearchStateTo(.sEntry)
		}
	}

	func handleArrow(_ arrow: ZArrowKey, with flags: ZEventFlags) {
		#if os(OSX)
		if  searchBoxIsFirstResponder {
			searchBox?.currentEditor()?.handleArrow(arrow, with: flags)
		} else if gIsSearchEssayMode {
			gEssayView?.handleArrow(arrow, flags: flags)
		}
		#endif
	}

	func handleEvent(_ event: ZEvent) -> ZEvent? {
		let    string = event.input ?? kEmpty
		let     flags = event.modifierFlags
		let   COMMAND = flags.isCommand
		let       key = string[string.startIndex].description
		let  isReturn = key == kReturn
		let     isTab = key == kTab
		let       isF = key == "f"
		let    isExit = kExitKeys.contains(key)
		let     state = gSearching.state
		let   isInBox = searchBoxIsFirstResponder
		let   isEntry = state == .sEntry
		let    isList = state == .sList

		if (gIsSearchEssayMode && !isInBox) || (key == "g" && COMMAND) {
			gEssayView?.handleKey(key, flags: flags)
		} else if  isList && !isInBox {
			return gSearchResultsController?.handleEvent(event)
		} else if isReturn, isInBox {
			updateSearchBox()
		} else if  key == "a" && COMMAND {
            searchBox?.selectAllText()
        } else if (isReturn && isEntry) || (isExit && !isF) || (isF && COMMAND) {
            endSearch()
		} else if isTab {
			gSearching.switchToList()
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

	func updateSearchBox() {
		if  let text = activeSearchBoxText,
			text.length > 0,
			![kEmpty, kSpace, "  "].contains(text) {
			gSearching.performSearch(for: text)
		} else {
			endSearch()
		}
	}

}
