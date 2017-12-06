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


    var favorites: [Zone] {
        var children = gFavoritesManager.workingFavorites
        var removals = IndexPath()

        for (iIndex, iChild) in children.enumerated() {
            if !iChild.isBookmark {
                removals.append(iIndex)
            }
        }

        while let index = removals.last {
            removals.removeLast()
            children.remove(at: index)
        }

        return children
    }


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        if ![.search, .found, .startup].contains(kind),
            let selector = favoritesSelector {

            selector.apportionsSegmentWidthsByContent = true
            selector.removeAllSegments()

            for (iIndex, iFavorite) in favorites.reversed().enumerated() {
                selector.insertSegment(withTitle: iFavorite.zoneName, at:iIndex, animated: false)
            }
        }
    }


    @IBAction func selectorAction(iControl: UISegmentedControl) {
        let    index = iControl.numberOfSegments - iControl.selectedSegment - 1
        let favorite = favorites[index]

        gFavoritesManager.travel(into: favorite) {
            self.syncToCloudAndSignalFor(nil, regarding: .redraw, onCompletion: nil)
        }
    }

}
