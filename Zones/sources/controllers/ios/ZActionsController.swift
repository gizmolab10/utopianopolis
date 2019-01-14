//
//  ZActionsController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 9/24/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import UIKit


enum ZActionTitle: String {
    case eCut     = "Cut"
    case eNew     = "New"
    case eNext    = "Next"
    case eUndo    = "Undo"
    case eHelp    = "Help"
    case eHang    = "Reconnect"
    case eFocus   = "Focus"
    case ePrefs   = "Preferences"
    case eTravel  = "Travel"
    case eRefresh = "Refresh"
}


class ZActionsController : ZGenericController {

    @IBOutlet var actionsSelector: UISegmentedControl?
    override  var    controllerID: ZControllerID { return .actions }
    var favorite: String { return gFavorites.actionTitle }


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        if ![.search, .found].contains(iKind),
            let          selector = actionsSelector {
            var             index = 0
            let            insert = { (iTitle: ZActionTitle) -> Void in
                let       isFocus = iTitle == ZActionTitle.eFocus
                let title: String = isFocus ? self.favorite : iTitle.rawValue

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
            insert(.eTravel)
            insert(.eRefresh)
            insert(.ePrefs)
            insert(.eHelp)
        }
    }


    @IBAction func selectorAction(iControl: UISegmentedControl) {
        if  let       title = iControl.titleForSegment(at: iControl.selectedSegment) {
            let actionTitle = actionTitleForTitle(title)

            switch actionTitle {
            case .eRefresh: refresh()
            case .eCut:     gGraphEditor.delete()
            case .eNew:     gGraphEditor.addIdea()
            case .eHang:    gBatch.unHang()
            case .eUndo:    gGraphEditor.undo.undo()
            case .eNext:    gGraphEditor.addNext() { iChild in iChild.edit() }
            case .eFocus:   gFocus.focus(kind: .eSelected) { gGraphEditor.redrawSyncRedraw() }
            case .eTravel:  gFocus.maybeTravelThrough(gSelecting.currentMoveable)
            case .ePrefs:   break
            case .eHelp:    break
            }
        }
    }


    func refresh() {
        gBatch.unHang()
        gWidgets     .clear()
        gEditorController?  .clear()
        gControllers        .startupCloudAndUI()
    }


    func actionTitleForTitle(_ iTitle: String) -> ZActionTitle {
        if  let action = ZActionTitle(rawValue: iTitle) {
            return action
        }

        return .eFocus
    }

}
