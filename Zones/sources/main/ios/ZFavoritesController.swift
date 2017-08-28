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
        if  let          selector = favoritesSelector {
            let     selectedIndex = selector.selectedSegmentIndex

            if  selectedIndex     < selector.numberOfSegments {
                let         width = selector.widthForSegment(at: selectedIndex)
                var             x = CGFloat(0.0)

                if  selectedIndex > 0 {
                    for index in 0 ... selectedIndex - 1 {
                        x        += selector.widthForSegment(at: index)
                    }
                }

                return CGRect(x: x, y: 0.0, width: width, height: 44.0)
            }
        }

        return CGRect.zero
    }


    override let controllerID = ZControllerID.favorites


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
                let  zone = gFavoritesManager.zoneAtIndex(index - 1)
                let title = zone?.zoneName ?? "ACK!"

                selector.insertSegment(withTitle: title, at: index, animated: false)

                let     width = title.widthForFont(UIFont.systemFont(ofSize: 13.0)) + 10.0
//                let   color = zone?.bookmarkTarget?.color ?? gDefaultZoneColor
//                let       s = selector.subviews[index]
//                s.tintColor = color // .lighter(by: 5.0)

                selector.setWidth(width, forSegmentAt: index)
            }

            selector.selectedSegmentIndex = min(selector.numberOfSegments - 1, gFavoritesManager.favoritesIndex + 1)

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
