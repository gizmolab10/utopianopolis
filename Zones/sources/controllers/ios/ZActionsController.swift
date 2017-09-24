//
//  ZActionsController.swift
//  Zones
//
//  Created by Jonathan Sand on 9/24/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import UIKit


enum ZActionID: Int {
    case eUndo
    case eDelete
    case eAddIdea
    case eAddSibling
    case eAddFavorite
}


class ZActionsController : ZGenericController {

    @IBOutlet var actionsSelector: UISegmentedControl?
    override  var    controllerID: ZControllerID { return .actions }


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        if ![.search, .found].contains(kind),
            let  selector = actionsSelector {

            selector.apportionsSegmentWidthsByContent = true
            selector.removeAllSegments()
            selector.insertSegment(withTitle: "Undo",    at:ZActionID       .eUndo.rawValue, animated: false)
            selector.insertSegment(withTitle: "Delete",  at:ZActionID     .eDelete.rawValue, animated: false)
            selector.insertSegment(withTitle: "Idea",    at:ZActionID    .eAddIdea.rawValue, animated: false)
            selector.insertSegment(withTitle: "Sibling", at:ZActionID .eAddSibling.rawValue, animated: false)
            selector.insertSegment(withTitle: "Focus",   at:ZActionID.eAddFavorite.rawValue, animated: false)
        }
    }


    @IBAction func selectorAction(iControl: UISegmentedControl) {
        if  let identifier = ZActionID(rawValue: iControl.selectedSegment) {
            switch identifier {
            case .eUndo:        gEditingManager.undoManager.undo()
            case .eDelete:      gEditingManager.delete()
            case .eAddIdea:     gEditingManager.createIdea()
            case .eAddSibling:  gEditingManager.createSiblingIdea() { iChild in iChild.edit() }
            case .eAddFavorite: gEditingManager.focus(on: gSelectionManager.firstGrab)
            }
        }
    }
}
