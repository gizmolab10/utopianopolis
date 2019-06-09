//
//  ZMainController.swift
//  Thoughtful
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


var gMainController: ZMainController? { return gControllers.controllerForID(.idMain) as? ZMainController }


class ZMainController: ZGenericController {


    @IBOutlet var detailsWidth:        NSLayoutConstraint?
    @IBOutlet var searchBoxHeight:     NSLayoutConstraint?
    @IBOutlet var searchResultsView:   ZView?
    @IBOutlet var searchBoxView:       ZView?
    @IBOutlet var detailView:          ZView?
    @IBOutlet var editorView:          ZView?
    override  var controllerID:        ZControllerID { return .idMain }


    override func setup() {
        searchBoxView?    .isHidden = true
        searchResultsView?.isHidden = true
    }


    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        let  hideSearch = gWorkMode != .searchMode
        let hideResults = hideSearch || !(gSearchResultsController?.hasResults ?? false)

        switch iKind {
        case .eFound:
            searchBoxView?        .isHidden = hideSearch
            searchResultsView?    .isHidden = hideResults
        case .eSearch:
            searchBoxView?        .isHidden = hideSearch

            if  hideSearch {
                searchResultsView?.isHidden = hideSearch

                assignAsFirstResponder(nil)
            }
        default: break
        }
    }
    
}
