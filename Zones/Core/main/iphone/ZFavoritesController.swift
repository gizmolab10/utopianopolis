//
//  ZFavoritesController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/6/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import UIKit


class ZFavoritesController: ZGenericController {


    @IBOutlet var favoritesSelector: UISegmentedControl?
    @IBOutlet var        scrollView: UIScrollView?


    var selectedRect: CGRect {
        if  let      selector = favoritesSelector {
            let selectedIndex = selector.selectedSegmentIndex
            let         width = selector.widthForSegment(at: selectedIndex)
            var             x = CGFloat(0.0)

            if selectedIndex > 0 {
                for index in 0 ... selectedIndex - 1 {
                    x            += selector.widthForSegment(at: index)
                }
            }

            return CGRect(x: x, y: 0.0, width: width, height: 44.0)
        }

        return CGRect.zero
    }


    override func identifier() -> ZControllerID { return .favorites }


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        let  here = gRemoteStoresManager.manifest(for: storageMode).hereZone

        gFavoritesManager.updateIndexFor(here) { object in
            gFavoritesManager.update()
            self.updateSelector()
        }
    }


    func updateSelector() {
        if  let selector = favoritesSelector {
            selector.removeAllSegments()

            for index in 0 ... gFavoritesManager.count {
                let title = gFavoritesManager.zoneAtIndex(index - 1)?.zoneName ?? "ACK!"
                let width = title.widthForFont(UIFont.systemFont(ofSize: 13.0)) + 10.0

                selector.insertSegment(withTitle: title, at: index, animated: false)
                selector.setWidth(width, forSegmentAt: index)
            }

            selector.selectedSegmentIndex = gFavoritesManager.favoritesIndex + 1

            scrollView?.scrollRectToVisible(selectedRect, animated: false)
        }
    }


    @IBAction func selectorAction(_ iControl: UISegmentedControl) {
        gFavoritesManager.favoritesIndex = iControl.selectedSegment - 1
        gFavoritesManager.refocus {
            self.redrawAndSync()
        }
    }

}
