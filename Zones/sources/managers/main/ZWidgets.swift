//
//  ZWidgets.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


let gWidgets = ZWidgets()


class ZWidgets: NSObject {


    var       widgets: [Int : ZoneWidget]  = [:]
    var currentEditingWidget: ZoneWidget? { return widgetForZone(gTextEditor.currentlyEditingZone) }
    var currentMovableWidget: ZoneWidget? { return widgetForZone(gSelecting.currentMoveable) }
    var firstGrabbableWidget: ZoneWidget? { return widgetForZone(gSelecting.firstGrab) }


    var visibleWidgets: [ZoneWidget] {
        let favorites = gFavoritesRoot?.visibleWidgets ?? []

        return gHere.visibleWidgets + favorites
    }


    func clearRegistry() {
        widgets = [:]
    }


    /// capture a ZoneWidget for later lookup by it's zone
    /// (see widgetForZone)
    ///
    /// - Parameter widget: UI element containing text, drag and reveal dots and children widgets
    func registerWidget(_ widget: ZoneWidget) {
        if  let           zone = widget.widgetZone {
            widgets[zone.hash] = widget
        }
    }


    /// Lookup previously registered ZoneWidget by its zone
    ///
    /// - Parameter iZone: Zone associated with previously registered ZoneWidget
    /// - Returns: ZoneWidget
    func widgetForZone(_ iZone: Zone?) -> ZoneWidget? {
        if  let zone = iZone {
            return widgets[zone.hash]
        }

        return nil
    }

}
