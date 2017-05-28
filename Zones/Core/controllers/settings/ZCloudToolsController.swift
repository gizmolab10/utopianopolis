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


class ZCloudToolsController: ZGenericTableController {


    override func identifier() -> ZControllerID { return .cloudTools }
    override func numberOfRows(in tableView: ZTableView) -> Int { return 3 }
    override func genericTableUpdate() {}


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


    @IBAction func recountButtonAction(_ button: NSButton) {
        gRoot?.progenyCountUpdate(.deep)
    }


    @IBAction func restoreZoneButtonAction(_ button: NSButton) {
        // similar to gEditingManager.moveInto
        if  let root = gRoot {
            let zone = gSelectionManager.firstGrab
            gHere    = root

            root.maybeNeedChildren()
            gOperationsManager.children(.expand, 1) {
                root.addAndReorderChild(zone, at: 0)
                zone.hideChildren()

                zone.traverseApply { (iChild: Zone) -> (ZTraverseStatus) in
                    iChild.isDeleted = false

                    return .eContinue
                }

                gControllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
            }
        }
    }
}
