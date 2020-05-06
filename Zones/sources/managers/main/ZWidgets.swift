//
//  ZWidgets.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit

let gWidgets = ZWidgets()

class ZWidgets: NSObject {

	var      mapWidgets: [Int : ZoneWidget]  = [:]
	var favoriteWidgets: [Int : ZoneWidget]  = [:]
    var   currentEditingWidget: ZoneWidget? { return widgetForZone(gTextEditor.currentlyEditingZone) }
    var   currentMovableWidget: ZoneWidget? { return widgetForZone(gSelecting.currentMoveable) }
    var   firstGrabbableWidget: ZoneWidget? { return widgetForZone(gSelecting.firstSortedGrab) }

    var visibleWidgets: [ZoneWidget] {
        let favorites = gFavoritesRoot?.visibleWidgets ?? []

        return gHere.visibleWidgets + favorites
    }

    func clearRegistry(forFavorites: Bool) {
		setWidgetsDict([:], forFavorites: forFavorites)
    }

	func getWidgetsDict(forFavorites: Bool) -> [Int : ZoneWidget] {
		return forFavorites ? favoriteWidgets : mapWidgets
	}

	func setWidgetsDict(_ dict: [Int : ZoneWidget], forFavorites: Bool) {
		if  forFavorites {
			favoriteWidgets = dict
		} else {
			mapWidgets      = dict
		}
	}

    /// capture a ZoneWidget for later lookup by it's zone
    /// (see widgetForZone)
    ///
    /// - Parameter widget: UI element containing text, drag and reveal dots and children widgets
    func registerWidget(_ widget: ZoneWidget) {
        if  let        zone = widget.widgetZone {
			let inFavorites = zone.isInFavorites
			var        dict = getWidgetsDict(forFavorites: inFavorites)

			dict[zone.hash] = widget

			setWidgetsDict(dict, forFavorites: inFavorites)
        }
    }

    /// Lookup previously registered ZoneWidget by its zone
    ///
    /// - Parameter iZone: Zone associated with previously registered ZoneWidget
    /// - Returns: ZoneWidget
    func widgetForZone(_ iZone: Zone?) -> ZoneWidget? {
        if  let zone = iZone {
			let dict = getWidgetsDict(forFavorites: zone.isInFavorites)

			return dict[zone.hash]
		}

        return nil
    }

}
