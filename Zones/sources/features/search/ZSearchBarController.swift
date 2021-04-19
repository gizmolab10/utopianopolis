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

	@IBOutlet var searchBox            : ZSearchField?
	@IBOutlet var dismissButton        : ZButton?
	@IBOutlet var searchOptionsControl : ZSegmentedControl?
	override  var controllerID         : ZControllerID { return .idSearch }

	var activeSearchBoxText: String? {
		let searchString = searchBox?.text?.searchable

		if  ["", " ", "  "].contains(searchString) {
			endSearch()

			return nil
		}

		return searchString
	}

	var searchBoxIsFirstResponder : Bool {
		#if os(OSX)
		if  let    first  = searchBox?.window?.firstResponder {
			return first == searchBox?.currentEditor()
		}
		#endif

		return false
	}

	// MARK:- events
	// MARK:-

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		if  iKind == .sSearch && gIsSearchMode {
			gSearching.state = .sEntry

			updateSearchOptions()

			FOREGROUND(after: 0.2) {
				self.searchBox?.becomeFirstResponder()
			}
		}
	}

	func handleArrow(_ arrow: ZArrowKey, with flags: ZEventFlags) {
		#if os(OSX)
		searchBox?.currentEditor()?.handleArrow(arrow, with: flags)
		#endif
	}

	func handleEvent(_ event: ZEvent) -> ZEvent? {
		let    string = event.input ?? ""
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

		if  isList && !isInBox {
			return gSearchResultsController?.handleEvent(event)
		} else if isReturn, isInBox, let text = activeSearchBoxText {
			gSearching.performSearch(for: text)
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

	func control(_ control: ZControl, textView: ZTextView, doCommandBy commandSelector: Selector) -> Bool { // false means not handled
		let done = commandSelector == Selector(("noop:"))

		if  done {
			endSearch()
		}

		return done
	}

	@IBAction func searchOptionAction(sender: ZSegmentedControl) {
		var options = ZFilterOption.fNone

		for index in 0..<sender.segmentCount {
			if  sender.isSelected(forSegment: index) {
				let option = ZFilterOption(rawValue: Int(2.0 ** Double(index)))
				options.insert(option)
			}
		}

		if  options == .fNone {
			options  = .fIdeas
		}

		gFilterOption = options

		if  let text = activeSearchBoxText,
			text.length > 0 {
			gSearching.performSearch(for: text)
		}
	}

	@IBAction func dismissAction(_ sender: ZButton) {
		endSearch()
	}

	// MARK:- private
	// MARK:-

	func updateSearchOptions() {
		let o = gFilterOption

		searchOptionsControl?.setSelected(o.contains(.fBookmarks), forSegment: 0)
		searchOptionsControl?.setSelected(o.contains(.fNotes),     forSegment: 1)
		searchOptionsControl?.setSelected(o.contains(.fIdeas),     forSegment: 2)
		searchOptionsControl?.action = #selector(searchOptionAction)
		searchOptionsControl?.target = self
	}

    func endSearch() {
        searchBox?.resignFirstResponder()
        gSearching.exitSearchMode()
    }

}
