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

    func handleEvent(_ event: ZEvent) -> ZEvent? {
		return gSearchBarController?.handleEvent(event)
    }

	var searchText: String? {
		get { return gSearchBarController?.searchBox?.text }
		set { gSearchBarController?.searchBox?.text = newValue }
	}

	func exitSearchMode() {
		state = .sNot

		swapModes()
		gSignal([.sFound])
		gSignal([.sSearch])
	}

	func swapModes() {
		let      last = priorWorkMode ??       .wBigMapMode
		priorWorkMode = gIsSearchMode ? nil  :    gWorkMode
		gWorkMode     = gIsSearchMode ? last : .wSearchMode
	}

	func showSearch(_ OPTION: Bool = false) {
		if  gDatabaseID  != .favoritesID {
			swapModes()
			gSignal([OPTION ? .sFound : .sSearch])
		}
	}

}
