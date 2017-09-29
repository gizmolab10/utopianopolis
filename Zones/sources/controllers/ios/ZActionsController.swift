//
//  ZActionsController.swift
//  Zones
//
//  Created by Jonathan Sand on 9/24/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import UIKit


enum ZActionTitle: String {
    case eHang    = "Reconnect"
    case eUndo    = "Undo"
    case eCut     = "Cut"
    case eNew     = "New"
    case eNext    = "Next"
    case eFocus   = "Focus"
    case ePrefs   = "Preferences"
    case eHelp    = "Help"
    case eRefresh = "Refresh"
}


typealias ActionClosure = (ZActionTitle) -> (Void)


class ZActionsController : ZGenericController {

    @IBOutlet var actionsSelector: UISegmentedControl?
    override  var    controllerID: ZControllerID { return .actions }
    var favorite: String { return gFavoritesManager.actionTitle }


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        if ![.search, .found].contains(kind),
            let              selector = actionsSelector {
            var                 index = 0
            let insert: ActionClosure = { iTitle -> Void in
                let           isFocus = iTitle == ZActionTitle.eFocus
                let     title: String = isFocus ? self.favorite : iTitle.rawValue

                selector.insertSegment(withTitle: title, at:index, animated: false)

                index += 1
            }

            selector.apportionsSegmentWidthsByContent = true
            selector.removeAllSegments()

            if gIsLate {
                insert(.eHang)
            }

            insert(.eUndo)
            insert(.eCut)
            insert(.eNew)
            insert(.eNext)
            insert(.eFocus)
            insert(.ePrefs)
            insert(.eHelp)
            insert(.eRefresh)
        }
    }


    @IBAction func selectorAction(iControl: UISegmentedControl) {
        if  let       title = iControl.titleForSegment(at: iControl.selectedSegment) {
            let actionTitle = actionTitleForTitle(title)

            switch actionTitle {
            case .eHang:    gOperationsManager.invokeResponse?(nil)
            case .eUndo:    gEditingManager.undoManager.undo()
            case .eCut:     gEditingManager.delete()
            case .eNew:     gEditingManager.createIdea()
            case .eNext:    gEditingManager.createSiblingIdea() { iChild in iChild.edit() }
            case .eFocus:   gEditingManager.focus(on: gSelectionManager.firstGrab)
            case .ePrefs:   break
            case .eHelp:    break
            case .eRefresh: break
            }
        }
    }


    func actionTitleForTitle(_ iTitle: String) -> ZActionTitle {
        if  let action = ZActionTitle(rawValue: iTitle) {
            return action
        }

        return .eFocus
    }

}
