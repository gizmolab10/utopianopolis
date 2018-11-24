//
//  ZSearchManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/6/17.
//  Copyright © 2017 Zones. All rights reserved.
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
}


let gSearchManager = ZSearchManager()


class ZSearchManager: NSObject {


    var state = ZSearchState.not
    var  searchController:        ZSearchController? { return gControllersManager.controllerForID(.searchBox)     as? ZSearchController }
    var resultsController: ZSearchResultsController? { return gControllersManager.controllerForID(.searchResults) as? ZSearchResultsController }


    func showResults(_ iResults: Any?) {
        gWorkMode = .searchMode
        state     = .list

        gControllersManager.signalFor(iResults as? NSObject, regarding: .found)
    }


    func exitSearchMode() {
        gWorkMode = .graphMode
        state     = .not

        gControllersManager.signalFor(nil, regarding: .found)
        gControllersManager.signalFor(nil, regarding: .search)
    }


    func handleKeyEvent(_ event: ZEvent) -> ZEvent? {
        switch state {
        case .list: return resultsController?.handleBrowseKeyEvent(event)
        default:    return  searchController?      .handleKeyEvent(event, with: state)
        }
    }

}
