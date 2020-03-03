//
//  ZSearching.swift
//  Thoughtful
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

    func exitSearchMode() {
		state = .sNot

		gControllers.swapModes()
        signalRegarding(.eFound)
        signalRegarding(.eSearch)
    }

    func handleEvent(_ event: ZEvent) -> ZEvent? {
		return gSearchController?.handleEvent(event)
    }

}
