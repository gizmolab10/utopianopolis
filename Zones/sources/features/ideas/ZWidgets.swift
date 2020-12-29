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

	var   bigMapWidgets: [Int : ZoneWidget]  = [:]
	var   recentWidgets: [Int : ZoneWidget]  = [:]
	var favoriteWidgets: [Int : ZoneWidget]  = [:]
	var exemplarWidgets: [Int : ZoneWidget]  = [:]
    var currentlyEditedWidget : ZoneWidget? { return widgetForZone(gTextEditor.currentlyEditedZone) }
    var  currentMovableWidget : ZoneWidget? { return widgetForZone(gSelecting.currentMoveable) }
    var  firstGrabbableWidget : ZoneWidget? { return widgetForZone(gSelecting.firstSortedGrab) }

    var visibleWidgets: [ZoneWidget] {
		let other = gIsRecentlyMode ? gRecentsRoot : gFavoritesRoot

        return gHere.visibleWidgets + (other?.visibleWidgets ?? [])
    }

    func clearRegistry(for type: ZWidgetType) {
		setZoneWidgetRegistry([:], for: type)
    }

	func getZoneWidgetRegistry(for type: ZWidgetType) -> [Int : ZoneWidget] {
		if type.isBigMap   { return   bigMapWidgets }
		if type.isRecent   { return   recentWidgets }
		if type.isFavorite { return favoriteWidgets }
		if type.isExemplar { return exemplarWidgets }

		return [:]
	}

	func setZoneWidgetRegistry(_ dict: [Int : ZoneWidget], for type: ZWidgetType) {
		if      type.isBigMap   {   bigMapWidgets = dict }
		else if type.isRecent   {   recentWidgets = dict }
		else if type.isFavorite { favoriteWidgets = dict }
		else if type.isExemplar { exemplarWidgets = dict }
	}

    /// capture a ZoneWidget for later lookup by it's zone
    /// (see widgetForZone)
    ///
    /// - Parameter widget: UI element containing text, drag and reveal dots and children widgets
	/// - type: indicates which dictionary to put the zone:widget pair in

	func setWidgetForZone( _ widget: ZoneWidget, for type: ZWidgetType) {
        if  let   zone = widget.widgetZone {
			var   dict = getZoneWidgetRegistry(for: type)
			let   hash = zone.hash
			dict[hash] = widget

			setZoneWidgetRegistry(dict, for: type)
		}
    }

    /// Lookup previously registered ZoneWidget by its zone
    ///
    /// - Parameter iZone: Zone associated with previously registered ZoneWidget
    /// - Returns: ZoneWidget
    func widgetForZone(_ iZone: Zone?) -> ZoneWidget? {
        if  let zone = iZone {
			let type = zone.type
			let dict = getZoneWidgetRegistry(for: type)

			return dict[zone.hash]
		}

        return nil
    }

}
