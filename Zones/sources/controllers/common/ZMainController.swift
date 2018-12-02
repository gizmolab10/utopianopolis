//
//  ZMainController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


var gMainController: ZMainController? { return gControllersManager.controllerForID(.main) as? ZMainController }


class ZMainController: ZGenericController {


    @IBOutlet var detailsWidth:       NSLayoutConstraint?
    @IBOutlet var searchBoxHeight:    NSLayoutConstraint?
    @IBOutlet var searchResultsView:  ZView?
    @IBOutlet var searchBoxView:      ZView?
    @IBOutlet var detailView:         ZView?
    @IBOutlet var editorView:         ZView?


    override func setup() {
        controllerID = .main

        searchBoxView?    .isHidden = true
        searchResultsView?.isHidden = true
    }


    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        let isSearch = gWorkMode == .searchMode

        switch iKind {
        case .found:
            searchResultsView?.isHidden = !isSearch || !(gSearchResultsController?.hasResults ?? false)
        case .search:
            searchBoxView?    .isHidden = !isSearch

            if !isSearch {
                searchResultsView?.isHidden = true

                assignAsFirstResponder(nil)
            }
        default: break
        }
    }

}
