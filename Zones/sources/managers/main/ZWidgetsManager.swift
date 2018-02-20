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


    var widgets: [Int :  ZoneWidget]  = [:]
    var    grid: [Int : [ZoneWidget]] = [:]
    var currentEditingWidget: ZoneWidget? { return widgetForZone(gTextManager.isEditing) }
    var currentMovableWidget: ZoneWidget? { return widgetForZone(gSelectionManager.currentMoveable) }
    var firstGrabbableWidget: ZoneWidget? { return widgetForZone(gSelectionManager.firstGrab) }


    var visibleWidgets: [ZoneWidget] {
        let favorites = gFavoritesManager.rootZone?.visibleWidgets ?? []

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


    func reindex() {
        if  let   view = gEditorView {
            let bounds = view.bounds
            grid       = [:]

            for widget in widgets.values {
                let   frame = widget.convert(widget.bounds, to: view)
                let indices = frame.indices(within: bounds, radix: 10)

                for index in indices {
                    if  grid[index] == nil {
                        grid[index] = []
                    }

                    grid[index]?.append(widget)
                }
            }
        }
    }

}
