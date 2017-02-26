//
//  ZWidgetsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZWidgetsManager: NSObject {


    var      widgets = [Int : ZoneWidget] ()
    var currentEditingWidget: ZoneWidget? { return widgetForZone(gSelectionManager.currentlyEditingZone) }
    var currentMovableWidget: ZoneWidget? { return widgetForZone(gSelectionManager.currentlyMovableZone) }
    var firstGrabbableWidget: ZoneWidget? { return widgetForZone(gSelectionManager.firstGrabbableZone) }


    func clear() {
        widgets.removeAll()
    }


    func registerWidget(_ widget: ZoneWidget) {
        if let zone = widget.widgetZone {
            widgets[zone.hash] = widget
        }
    }


    func unregisterWidget(_ widget: ZoneWidget) {

        // only unlink the zone from its current widget

        if let zone = widget.widgetZone, widgets[zone.hash] == widget {
            widgets[zone.hash] = nil
        }
    }


    func widgetForZone(_ zone: Zone?) -> ZoneWidget? {
        return zone == nil ? nil : widgets[zone!.hash]
    }
}
