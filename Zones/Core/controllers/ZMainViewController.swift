//
//  ZMainViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZMainViewController: ZGenericViewController {


    @IBOutlet var searchBoxHeight:   NSLayoutConstraint?
    @IBOutlet var searchResultsView: NSView?
    @IBOutlet var searchBoxView:     NSView?
    @IBOutlet var editorView:        NSView?
    @IBOutlet var mainView:          NSView?


    override func identifier() -> ZControllerID { return .main }


    override func awakeFromNib() {
        searchBoxView?.removeConstraint(searchBoxHeight!)
        searchBoxView?.snp.makeConstraints({ (make) in
            make.height.equalTo(0.0)
        })

        dispatchAsyncInForegroundAfter(0.1) { // can't be done during awakeFromNib
            self.searchResultsView?.removeFromSuperview()
        }
    }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        switch kind {
        case .found:
            let isSearching = workMode == .searchMode

            // show(false, view: <#T##ZView#>)
            show ( isSearching, view: searchResultsView!)
            show (!isSearching, view: editorView!)

            break
        case .search:
            searchBoxView?.snp.removeConstraints()
            searchBoxView?.snp.makeConstraints({ (make) in
                make.height.equalTo(showsSearching ? 44.0 : 0.0)
            })

            if !showsSearching {
                mainWindow.makeFirstResponder(nil)
            }

            break
        default:

            break
        }
    }


    func show(_ show: Bool, view: ZView) {
        if !show {
            view.removeFromSuperview()
        } else if !(mainView?.subviews.contains(view))! {
            mainView?.addSubview(view)
            view.snp.makeConstraints({ (make) in
                make.top.bottom.left.right.equalTo(mainView!)
            })
        }
    }

}
