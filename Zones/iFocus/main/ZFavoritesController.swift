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


    override func identifier() -> ZControllerID { return .favorites }


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        let  here = gRemoteStoresManager.manifest(for: storageMode).hereZone

        gFavoritesManager.updateIndexFor(here) { object in
            gFavoritesManager.update()
            self.updateSelector()
        }
    }


    func updateSelector() {
        favoritesSelector?.removeAllSegments()

        for index in 0 ... gFavoritesManager.count {
            let title = gFavoritesManager.zoneAtIndex(index - 1)?.zoneName ?? "ACK!"
            let width = title.widthForFont(UIFont.systemFont(ofSize: 14.0)) + 5.0

            favoritesSelector?.insertSegment(withTitle: title, at: index, animated: false)
            favoritesSelector?.setWidth(width, forSegmentAt: index)
        }

        favoritesSelector?.selectedSegmentIndex = gFavoritesManager.favoritesIndex + 1
    }


    @IBAction func selectorAction(_ iControl: UISegmentedControl) {
        gFavoritesManager.favoritesIndex = iControl.selectedSegment - 1
        gFavoritesManager.refocus {
            self.signalFor(nil, regarding: .redraw)
        }
    }

}
