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
    case eCut
    case eNew
    case eNext
    case eFocus
}


class ZActionsController : ZGenericController {

    @IBOutlet var actionsSelector: UISegmentedControl?
    override  var    controllerID: ZControllerID { return .actions }
    var favorite: String { return gFavoritesManager.actionTitle }


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        if ![.search, .found].contains(kind),
            let  selector = actionsSelector {

            selector.apportionsSegmentWidthsByContent = true
            selector.removeAllSegments()
            selector.insertSegment(withTitle: "Undo",   at:ZActionID .eUndo.rawValue, animated: false)
            selector.insertSegment(withTitle: "Cut",    at:ZActionID  .eCut.rawValue, animated: false)
            selector.insertSegment(withTitle: "New",    at:ZActionID  .eNew.rawValue, animated: false)
            selector.insertSegment(withTitle: "Next",   at:ZActionID .eNext.rawValue, animated: false)
            selector.insertSegment(withTitle: favorite, at:ZActionID.eFocus.rawValue, animated: false)
        }
    }


    @IBAction func selectorAction(iControl: UISegmentedControl) {
        if  let identifier = ZActionID(rawValue: iControl.selectedSegment) {
            switch identifier {
            case .eUndo:  gEditingManager.undoManager.undo()
            case .eCut:   gEditingManager.delete()
            case .eNew:   gEditingManager.createIdea()
            case .eNext:  gEditingManager.createSiblingIdea() { iChild in iChild.edit() }
            case .eFocus: gEditingManager.focus(on: gSelectionManager.firstGrab)
            }
        }
    }
}
