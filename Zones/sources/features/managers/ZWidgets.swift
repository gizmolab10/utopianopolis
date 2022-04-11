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

	var   bigMapWidgets: WidgetHashDictionary = [:]
	var   recentWidgets: WidgetHashDictionary = [:]
	var favoriteWidgets: WidgetHashDictionary = [:]
	var exemplarWidgets: WidgetHashDictionary = [:]
    var currentlyEditedWidget : ZoneWidget?     { return widgetForZone(gTextEditor.currentlyEditedZone) }
    var  currentMovableWidget : ZoneWidget?     { return widgetForZone(gSelecting.currentMoveable) }
    var  firstGrabbableWidget : ZoneWidget?     { return widgetForZone(gSelecting.firstSortedGrab) }
    var        visibleWidgets : ZoneWidgetArray { return gHere.visibleWidgets + (gSmallMapHere?.visibleWidgets ?? []) }

	func clearAll() {
		bigMapWidgets  .clear()
		recentWidgets  .clear()
		favoriteWidgets.clear()
		exemplarWidgets.clear()
	}

	func allWidgets(for type: ZWidgetType) -> ZoneWidgetArray? {
		switch type {
			case .tExemplar: return exemplarWidgets.justWidgets
			default:         return bigMapWidgets.justWidgets + recentWidgets.justWidgets + favoriteWidgets.justWidgets
		}
	}

	func getZoneWidgetRegistry(for type: ZWidgetType?) -> WidgetHashDictionary? {
		if  let t = type {
			if  t.isBigMap   { return   bigMapWidgets }
			if  t.isRecent   { return   recentWidgets }
			if  t.isFavorite { return favoriteWidgets }
			if  t.isExemplar { return exemplarWidgets }
		}

		return nil
	}

	func setZoneWidgetRegistry(_ dict: WidgetHashDictionary, for type: ZWidgetType) {
		if      type.isBigMap   {   bigMapWidgets = dict }
		else if type.isRecent   {   recentWidgets = dict }
		else if type.isFavorite { favoriteWidgets = dict }
		else if type.isExemplar { exemplarWidgets = dict }
	}

    /// capture a ZoneWidget for later lookup by it's zone
    /// (see widgetForZone)
    ///
    /// - Parameter widget: UI element containing text, drag and reveal dots and children widgets
	/// - Parameter type: indicates which dictionary to put the zone:widget pair in

	func setWidgetForZone( _ widget: ZoneWidget, for type: ZWidgetType) {
        if  let   zone = widget.widgetZone,
			var   dict = getZoneWidgetRegistry(for: type) {
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
			let type = zone.widgetType
			if  let dict = getZoneWidgetRegistry(for: type) {
				return dict[zone.hash]
			}
		}

        return nil
    }

}

extension WidgetHashDictionary {

	var justWidgets : ZoneWidgetArray { return ZoneWidgetArray(values) }

}