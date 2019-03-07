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
    case entry
    case find
    case list
    case not
    
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


    var state = ZSearchState.not


    func exitSearchMode() {
        gWorkMode = .graphMode
        state     = .not

        gControllers.signalFor(nil, regarding: .eFound)
        gControllers.signalFor(nil, regarding: .eSearch)
    }


    func handleEvent(_ event: ZEvent) -> ZEvent? {
        switch state {
        case .list: return gSearchResultsController?.handleEvent(event)
        default:    return gSearchController?       .handleEvent(event)
        }
    }

}
