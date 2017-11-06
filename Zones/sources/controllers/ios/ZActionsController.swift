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
    case eCut     = "Cut"
    case eNew     = "New"
    case eNext    = "Next"
    case eUndo    = "Undo"
    case eHelp    = "Help"
    case eHang    = "Reconnect"
    case eFocus   = "Focus"
    case ePrefs   = "Preferences"
    case eRefresh = "Refresh"
}


class ZActionsController : ZGenericController {

    @IBOutlet var actionsSelector: UISegmentedControl?
    override  var    controllerID: ZControllerID { return .actions }
    var favorite: String { return gFavoritesManager.actionTitle }


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        if ![.search, .found].contains(kind),
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
            insert(.eRefresh)
            insert(.ePrefs)
            insert(.eHelp)
        }
    }


    @IBAction func selectorAction(iControl: UISegmentedControl) {
        if  let       title = iControl.titleForSegment(at: iControl.selectedSegment) {
            let actionTitle = actionTitleForTitle(title)

            switch actionTitle {
            case .eHang:    gDBOperationsManager.unHang()
            case .eUndo:    gEditingManager.undoManager.undo()
            case .eCut:     gEditingManager.delete()
            case .eNew:     gEditingManager.createIdea()
            case .eNext:    gEditingManager.createNext() { iChild in iChild.edit() }
            case .eFocus:   gEditingManager.focus(on: gSelectionManager.firstGrab)
            case .ePrefs:   break
            case .eHelp:    break
            case .eRefresh: refresh()
            }
        }
    }


    func refresh() {
        gHere.needProgeny()
        gManifest.needFetch()
        gDBOperationsManager.unHang()
        gFavoritesManager.rootZone?.needChildren()

        gFavoritesManager.rootZone?.children = []

        gDBOperationsManager.children(.restore) {
            self.signalFor(nil, regarding: .data)
        }
    }


    func actionTitleForTitle(_ iTitle: String) -> ZActionTitle {
        if  let action = ZActionTitle(rawValue: iTitle) {
            return action
        }

        return .eFocus
    }

}
