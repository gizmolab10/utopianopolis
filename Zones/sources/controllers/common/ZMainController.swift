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


    override  var controllerID:       ZControllerID { return .main }
    @IBOutlet var searchBoxHeight:    NSLayoutConstraint?
    @IBOutlet var authenticationView: ZView?
    @IBOutlet var searchResultsView:  ZView?
    @IBOutlet var searchBoxView:      ZView?
    @IBOutlet var overlaysView:       ZView?
    @IBOutlet var editorView:         ZView?


    override func awakeFromNib() {
        searchBoxView?.removeConstraint(searchBoxHeight!)
        searchBoxView?.snp.makeConstraints { make in
            make.height.equalTo(0.0)
        }

        FOREGROUND(after: 0.1) { // can't be done during awakeFromNib
            self.searchResultsView?.removeFromSuperview()
        }
    }


    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        switch iKind {
        case .found:
            showAsSearching(gWorkMode == .searchMode)
        case .search:
            searchBoxView?.snp.removeConstraints()
            searchBoxView?.snp.makeConstraints { make in
                make.height.equalTo(gWorkMode == .searchMode ? 44.0 : 0.0)
            }

            if  gWorkMode != .searchMode {
                assignAsFirstResponder(nil)
                showAsSearching(false)
            }
        default: break
        }
    }


    func showAsSearching(_ iSearching: Bool) {
        gWorkMode = iSearching ? .searchMode : .graphMode

        show( iSearching, view: searchResultsView!)
        show(!iSearching, view: editorView!)
    }


    func show(_ show: Bool, view: ZView) {
        if !show {
            view.removeFromSuperview()
        } else if !(overlaysView?.subviews.contains(view))! {
            overlaysView?.addSubview(view)
            view.snp.makeConstraints { make in
                make.top.bottom.left.right.equalTo(overlaysView!)
            }
        }
    }

}
