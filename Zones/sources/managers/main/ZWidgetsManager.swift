//
//  ZWidgetsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


let gWidgetsManager = ZWidgetsManager()


class ZWidgetsManager: NSObject {


    var       widgets: [Int : ZoneWidget]  = [:]
    var currentEditingWidget: ZoneWidget? { return widgetForZone(gTextManager.currentlyEditingZone) }
    var currentMovableWidget: ZoneWidget? { return widgetForZone(gSelectionManager.currentMoveable) }
    var firstGrabbableWidget: ZoneWidget? { return widgetForZone(gSelectionManager.firstGrab) }


    var visibleWidgets: [ZoneWidget] {
        let favorites = gMineCloudManager.favoritesZone?.visibleWidgets ?? []

        return gHere.visibleWidgets + favorites
    }


    func clearRegistry() {
        widgets = [:]
    }


    func registerWidget(_ widget: ZoneWidget) {
        if  let           zone = widget.widgetZone {
            widgets[zone.hash] = widget
        }
    }


    func widgetForZone(_ iZone: Zone?) -> ZoneWidget? {
        if  let zone = iZone {
            return widgets[zone.hash]
        }

        return nil
    }

}
