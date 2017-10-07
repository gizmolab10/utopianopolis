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
    case gone
    case ready
    case input
    case browse
}


class ZSearchManager: NSObject {


    var state = ZSearchState.gone
    var  searchController:        ZSearchController? { return gControllersManager.controllerForID(.searchBox)     as? ZSearchController }
    var resultsController: ZSearchResultsController? { return gControllersManager.controllerForID(.searchResults) as? ZSearchResultsController }


    func showResults(_ iResults: Any?) {
        gWorkMode = .searchMode
        state     = .browse

        signalFor(iResults as? NSObject, regarding: .found)
    }


    func exitSearchMode() {
        gWorkMode = .editMode
        state     = .gone

        signalFor(nil, regarding: .found)
        signalFor(nil, regarding: .search)
    }


    func handleKeyEvent(_ event: ZEvent) -> ZEvent? {
        switch state {
        case .browse: return resultsController?.handleBrowseKeyEvent(event)
        default:      return  searchController?      .handleKeyEvent(event, with: state)
        }
    }

}
