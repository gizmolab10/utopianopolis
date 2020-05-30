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

	var      mainWidgets: [Int : ZoneWidget]  = [:]
	var   recentWidgets: [Int : ZoneWidget]  = [:]
	var favoriteWidgets: [Int : ZoneWidget]  = [:]
    var   currentEditingWidget: ZoneWidget? { return widgetForZone(gTextEditor.currentlyEditingZone) }
    var   currentMovableWidget: ZoneWidget? { return widgetForZone(gSelecting.currentMoveable) }
    var   firstGrabbableWidget: ZoneWidget? { return widgetForZone(gSelecting.firstSortedGrab) }

    var visibleWidgets: [ZoneWidget] {
        let favorites = gFavoritesRoot?.visibleWidgets ?? []
		let   recents =  gRecents.root?.visibleWidgets ?? []

        return gHere.visibleWidgets + favorites + recents
    }

    func clearRegistry(for type: ZWidgetType) {
		setWidgetsDict([:], for: type)
    }

	func getWidgetsDict(for type: ZWidgetType) -> [Int : ZoneWidget] {
		if type.isMap     { return     mainWidgets }
		if type.isRecent   { return   recentWidgets }
		if type.isFavorite { return favoriteWidgets }

		return [:]
	}

	func setWidgetsDict(_ dict: [Int : ZoneWidget], for type: ZWidgetType) {
		if      type.isMap     {     mainWidgets = dict }
		else if type.isRecent   {   recentWidgets = dict }
		else if type.isFavorite { favoriteWidgets = dict }
	}

    /// capture a ZoneWidget for later lookup by it's zone
    /// (see widgetForZone)
    ///
    /// - Parameter widget: UI element containing text, drag and reveal dots and children widgets
	func registerWidget(_ widget: ZoneWidget, for type: ZWidgetType) {
        if  let zone = widget.widgetZone {
			var dict = getWidgetsDict(for: type)

			dict[zone.hash] = widget

			setWidgetsDict(dict, for: type)
        }
    }

    /// Lookup previously registered ZoneWidget by its zone
    ///
    /// - Parameter iZone: Zone associated with previously registered ZoneWidget
    /// - Returns: ZoneWidget
    func widgetForZone(_ iZone: Zone?) -> ZoneWidget? {
        if  let zone = iZone {
			let type = zone.type
			let dict = getWidgetsDict(for: type)

			return dict[zone.hash]
		}

        return nil
    }

}
