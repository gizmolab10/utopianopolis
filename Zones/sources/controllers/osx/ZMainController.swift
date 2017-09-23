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


    override  var controllerID:      ZControllerID { return .main }
    @IBOutlet var searchBoxHeight:   NSLayoutConstraint?
    @IBOutlet var searchResultsView: ZView?
    @IBOutlet var searchBoxView:     ZView?
    @IBOutlet var overlaysView:      ZView?
    @IBOutlet var editorView:        ZView?


    override func awakeFromNib() {
        searchBoxView?.removeConstraint(searchBoxHeight!)
        searchBoxView?.snp.makeConstraints { (make: ConstraintMaker) in
            make.height.equalTo(0.0)
        }

        FOREGROUND(after: 0.1) { // can't be done during awakeFromNib
            self.searchResultsView?.removeFromSuperview()
        }
    }


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        switch kind {
        case .found:
            showAsSearching(gWorkMode == .searchMode)

            break
        case .search:
            searchBoxView?.snp.removeConstraints()
            searchBoxView?.snp.makeConstraints { (make: ConstraintMaker) in
                make.height.equalTo(gShowsSearching ? 44.0 : 0.0)
            }

            if !gShowsSearching {
                assignAsFirstResponder(nil)
                showAsSearching(false)
            }

            break
        default:

            break
        }
    }


    func showAsSearching(_ iSearching: Bool) {
        gWorkMode = iSearching ? .searchMode : .editMode

        show( iSearching, view: searchResultsView!)
        show(!iSearching, view: editorView!)
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
