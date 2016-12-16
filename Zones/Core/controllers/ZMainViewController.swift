//
//  ZMainViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZMainViewController: ZGenericViewController {


    @IBOutlet var searchBoxHeight: NSLayoutConstraint?
    @IBOutlet var searchResultsView: NSView?
    @IBOutlet var editorView: NSView?


    override func identifier() -> ZControllerID { return .main }


    override func awakeFromNib() {
        searchBoxHeight?.constant = 0
    }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        switch kind {
        case .search:
            showsSearching            = object != nil
            searchBoxHeight?.constant = showsSearching ? 44.0 : 0.0

            break
        case .found:
            let         results: [Any]? = object as? [Any]
            let             hideResults = results == nil || (results?.count)! == 0
            searchResultsView?.isHidden =  hideResults
            editorView?       .isHidden = !hideResults
            break
        default:

            break
        }
    }
}
