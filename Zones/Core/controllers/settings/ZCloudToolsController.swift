//
//  ZCloudToolsController.swift
//  Zones
//
//  Created by Jonathan Sand on 4/13/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZCloudToolsController: ZGenericController {


    override func identifier() -> ZControllerID { return .cloudTools }


    // MARK:- actions
    // MARK:-


    @IBAction func emptyTrashButtonAction(_ button: NSButton) {

        // needs elaborate gui, like search results, but with checkboxes and [de]select all checkbox

        //gOperationsManager.emptyTrash {
        //    self.note("eliminated")
        //}
    }


    @IBAction func restoreFromTrashButtonAction(_ button: NSButton) {
        gOperationsManager.undelete {
            self.signalFor(nil, regarding: .redraw)
        }

    }


    @IBAction func restoreZoneButtonAction(_ button: NSButton) {
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
}
