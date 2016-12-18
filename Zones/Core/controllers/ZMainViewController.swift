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
    @IBOutlet var searchBoxView:     NSView?
    @IBOutlet var editorView:        NSView?
    @IBOutlet var mainView:          NSView?


    override func identifier() -> ZControllerID { return .main }


    override func awakeFromNib() {
        searchBoxView?.removeConstraint(searchBoxHeight!)
        searchBoxView?.snp.makeConstraints({ (make) in
            make.height.equalTo(0.0)
        })
    }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        switch kind {
        case .search:
            searchBoxView?.snp.removeConstraints()
            searchBoxView?.snp.makeConstraints({ (make) in
                make.height.equalTo(showsSearching ? 44.0 : 0.0)
            })

            if !showsSearching {
                mainWindow.makeFirstResponder(nil)
            }

            break
        case .found:
            if workMode == .search {
                editorView?.removeFromSuperview()
            } else if !view.subviews.contains(editorView!) {
                mainView?.addSubview(editorView!)
                editorView?.snp.makeConstraints({ (make) in
                    make.top.bottom.left.right.equalTo(mainView!)
                })
            }

            break
        default:

            break
        }
    }
}
