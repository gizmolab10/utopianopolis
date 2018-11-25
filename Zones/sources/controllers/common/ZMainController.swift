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

        show( iSearching, iView: searchResultsView!, inView: view)
        show(!iSearching, iView: editorView!,        inView: view)
        show(!iSearching, iView: detailView!,        inView: view)
    }


    func show(_ show: Bool, iView: ZView, inView: ZView) {
        if !show {
            iView.removeFromSuperview()
        } else if !(inView.subviews.contains(iView)) {
            inView.addSubview(iView)
            iView.snp.makeConstraints { make in
                if inView == view {
                    make.bottom.left.equalTo(inView)
                    make.top.equalTo((gEditorController!.favoritesRootWidget.snp.bottom)).offset(20.0)
                } else {
                    make.top.bottom.left.right.equalTo(inView)
                }
            }
        }
    }

}
