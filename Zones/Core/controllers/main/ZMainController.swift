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


class ZMainController: ZGenericController {


    @IBOutlet var searchBoxHeight:   NSLayoutConstraint?
    @IBOutlet var searchResultsView: ZView?
    @IBOutlet var searchBoxView:     ZView?
    @IBOutlet var overlaysView:      ZView?
    @IBOutlet var editorView:        ZView?


    override func identifier() -> ZControllerID { return .main }


    override func awakeFromNib() {
        searchBoxView?.removeConstraint(searchBoxHeight!)
        searchBoxView?.snp.makeConstraints { (make: ConstraintMaker) in
            make.height.equalTo(0.0)
        }

        dispatchAsyncInForegroundAfter(0.1) { // can't be done during awakeFromNib
            self.searchResultsView?.removeFromSuperview()
        }
    }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        switch kind {
        case .found:
            let isSearching = gWorkMode == .searchMode

            // show(false, view: <#T##ZView#>)
            show( isSearching, view: searchResultsView!)
            show(!isSearching, view: editorView!)

            break
        case .search:
            searchBoxView?.snp.removeConstraints()
            searchBoxView?.snp.makeConstraints { (make: ConstraintMaker) in
                make.height.equalTo(gShowsSearching ? 44.0 : 0.0)
            }

            if !gShowsSearching {
                assignAsFirstResponder(nil)
            }

            break
        default:

            break
        }
    }


    func show(_ show: Bool, view: ZView) {
        if !show {
            view.removeFromSuperview()
        } else if !(overlaysView?.subviews.contains(view))! {
            overlaysView?.addSubview(view)
            view.snp.makeConstraints { (make: ConstraintMaker) in
                make.top.bottom.left.right.equalTo(overlaysView!)
            }
        }
    }

}
