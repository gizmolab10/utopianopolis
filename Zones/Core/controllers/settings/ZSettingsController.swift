//
//  ZSettingsController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZSliderKind: String {
    case Vertical   = "vertical"
    case Thickness  = "thickness"
    case Horizontal = "horizontal"
}


enum ZColorBoxKind: String {
    case Zones       = "zones"
    case Bookmarks   = "bookmarks"
    case Background  = "background"
    case DragTargets = "drag targets"
}


struct ZSettingsViewID: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let Information = ZSettingsViewID(rawValue: 1 << 0)
    static let Preferences = ZSettingsViewID(rawValue: 1 << 1)
    static let   Favorites = ZSettingsViewID(rawValue: 1 << 2)
    static let       Cloud = ZSettingsViewID(rawValue: 1 << 3)
    static let        Help = ZSettingsViewID(rawValue: 1 << 4)
    static let         All = ZSettingsViewID(rawValue: 0xFFFF)
}


class ZSettingsController: ZGenericController, ZTableViewDelegate, ZTableViewDataSource {

    @IBOutlet var     favoritesTableHeight: NSLayoutConstraint?
    @IBOutlet var       favoritesTableView: ZTableView?


    // MARK:- generic methods
    // MARK:-

    
    override func identifier() -> ZControllerID { return .settings }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        if  let tableView = favoritesTableView {
            gFavoritesManager.updateIndexFor(gHere) { object in
                gFavoritesManager.update()
                tableView.reloadData()

                self.favoritesTableHeight?.constant = CGFloat((gFavoritesManager.count + 1) * 19)
            }
        }
    }


    func displayViewFor(id: ZSettingsViewID) {
        let type = ZStackableView.self.className()

        gSettingsViewIDs.insert(id)
        view.applyToAllSubviews { (iView: ZView) in
            if  iView.className == type, let stackView = iView as? ZStackableView {
                stackView.update()
            }
        }
    }


    // MARK:- cloud tool actions
    // MARK:-
    

    @IBAction func emptyTrashButtonAction(_ button: ZButton) {

        // needs elaborate gui, like search results, but with checkboxes and [de]select all checkbox

        //gOperationsManager.emptyTrash {
        //    self.toConsole("eliminated")
        //}
    }


    @IBAction func restoreFromTrashButtonAction(_ button: ZButton) {
        gOperationsManager.undelete {
            self.signalFor(nil, regarding: .redraw)
        }
        
    }


    @IBAction func restoreZoneButtonAction(_ button: ZButton) {
        // similar to gEditingManager.moveInto
        let       zone = gSelectionManager.firstGrabbedZone
        gHere          = gRoot
        zone.isDeleted = false


        gRoot.maybeNeedChildren()
        gOperationsManager.children(recursiveGoal: 1) {
            gRoot.addAndReorderChild(zone, at: 0)
            gControllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
        }
    }


    @IBAction func pushToCloudButtonAction(_ button: ZButton) {
        gCloudManager.royalFlush {}
    }


    // MARK:- favorites table
    // MARK:-


    func numberOfRows(in tableView: ZTableView) -> Int {
        var count = 1

        for zone in gFavoritesManager.favoritesRootZone.children {
            if zone.isBookmark {
                count += 1
            }
        }

        return count
    }

    
    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        var        value = ""

        if  let     text = row == 0 ? "Edit ..." : gFavoritesManager.textAtIndex(row - 1) {
            let needsDot = gFavoritesManager.favoritesIndex == row - 1
            let   prefix = needsDot ? "•" : "  "
            value        = " \(prefix) \(text)"
        }
        
        return value
    }


    func actOnSelection(_ row: Int) {
        gSelectionManager.fullResign()

        if row == 0 {
            gStorageMode = .favorites

            gTravelManager.travel {
                self.signalFor(nil, regarding: .redraw)
            }
        } else if let zone: Zone = gFavoritesManager.zoneAtIndex(row - 1) {
            gFavoritesManager.favoritesIndex = row - 1

            gEditingManager.focusOnZone(zone)
        }
    }


    func tableView(_ tableView: ZTableView, shouldSelectRow row: Int) -> Bool {
        let select = gOperationsManager.isReady

        if  select {
            actOnSelection(row)
        }

        return false
    }

}
