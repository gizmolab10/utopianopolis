//
//  ZFavoritesController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 9/22/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import UIKit


class ZFavoritesController : ZGenericController {

    @IBOutlet var favoritesSelector: UISegmentedControl?
    override  var      controllerID: ZControllerID { return .favorites }


    var favorites: [Zone] {
        var children = gFavorites.workingFavorites
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


    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        if ![.eSearch, .eFound, .eStartup].contains(iKind),
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

        gFocusing.focus(through: favorite) {
            gControllers.syncToCloudAfterSignalFor(nil, regarding: .eRelayout, onCompletion: nil)
        }
    }

}
