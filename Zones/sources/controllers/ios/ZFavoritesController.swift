//
//  ZFavoritesController.swift
//  Zones
//
//  Created by Jonathan Sand on 9/22/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import UIKit


class ZFavoritesController : ZGenericController {

    @IBOutlet var favoritesSelector: UISegmentedControl?
    override  var      controllerID: ZControllerID { return .favorites }


    // MARK:- events
    // MARK:-


    @IBAction func selectorAction(iControl: UISegmentedControl) {
        let       index = iControl.selectedSegment

        if let favorite = gFavoritesManager.rootZone?[index] {
            gFavoritesManager.focus(on: favorite) {
                self.syncToCloudAndSignalFor(nil, regarding: .redraw, onCompletion: nil)
            }
        }
    }


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        if ![.search, .found, .startup].contains(kind),
            let favorites = gFavoritesManager.rootZone?.children,
            let  selector = favoritesSelector {
            selector.removeAllSegments()

            for (iIndex, iFavorite) in favorites.enumerated() {
                selector.insertSegment(withTitle: iFavorite.zoneName, at:iIndex, animated: false)
            }
        }
    }



}
