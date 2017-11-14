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


    var widgets = [ZStorageMode : [Int : ZoneWidget]] ()
    var currentEditingWidget: ZoneWidget? { return widgetForZone(gSelectionManager.currentlyEditingZone) }
    var currentMovableWidget: ZoneWidget? { return widgetForZone(gSelectionManager.currentMoveable) }
    var firstGrabbableWidget: ZoneWidget? { return widgetForZone(gSelectionManager.firstGrab) }


    var visibleWidgets: [ZoneWidget] {
        let favorites = gFavoritesManager.rootZone?.visibleWidgets ?? []

        return gHere.visibleWidgets + favorites
    }


    func clear() {
        widgets = [ZStorageMode : [Int : ZoneWidget]] ()
    }


    func registerWidget(_ widget: ZoneWidget) {
        if  let                      zone = widget.widgetZone,
            let                      mode = mode(for: zone) {
            var dict: [Int : ZoneWidget]? = widgets[mode]

            if dict == nil {
                dict = [:]
            }

            dict![zone.hash] = widget
            widgets[mode]    = dict
        }
    }


    func unregisterWidget(_ widget: ZoneWidget) {

        // only unlink the zone from its current widget

        if  let zone = widget.widgetZone, let mode = zone.storageMode, var dict = widgets[mode] {
            dict[zone.hash] = nil
            widgets[mode]   = dict
        }
    }


    func widgetForZone(_ zone: Zone?) -> ZoneWidget? {
        if  let mode = mode(for: zone), var dict = widgets[mode] {
            return dict[zone!.hash]
        }

        return nil
    }


    private func mode(for iZone: Zone?) -> ZStorageMode? {
        if let zone = iZone {
            if zone.isInFavorites {
                return .favoritesMode
            }

            return zone.storageMode
        }

        return nil
    }

}
