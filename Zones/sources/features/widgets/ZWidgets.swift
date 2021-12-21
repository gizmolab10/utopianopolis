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
		bigMapWidgets   = [:]
		recentWidgets   = [:]
		favoriteWidgets = [:]
		exemplarWidgets = [:]
	}

	func  allWidgets(for type: ZWidgetType) -> ZoneWidgetArray? {
		switch type {
			case .tExemplar: return exemplarWidgets.justWidgets
			default:         return bigMapWidgets.justWidgets + recentWidgets.justWidgets + favoriteWidgets.justWidgets
		}
	}

    func clearRegistry(for type: ZWidgetType) {
		setZoneWidgetRegistry([:], for: type)
    }

	func getZoneWidgetRegistry(for type: ZWidgetType) -> WidgetHashDictionary {
		if type.isBigMap   { return   bigMapWidgets }
		if type.isRecent   { return   recentWidgets }
		if type.isFavorite { return favoriteWidgets }
		if type.isExemplar { return exemplarWidgets }

		return [:]
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
			let type = zone.widgetType
			let dict = getZoneWidgetRegistry(for: type)

			return dict[zone.hash]
		}

        return nil
    }

	// MARK: - static methods
	// MARK: -
	
	static func placesCount(at iLevel: Int) -> Int {
		var  level = iLevel
		var  total = 1
		
		while true {
			let cCount = maxVisibleChildren(at: level)
			level     -= 1
			
			if  cCount > 0 {
				total *= cCount
			}
			
			if  level  < 0 {
				return total
			}
		}
	}
	
	static func maxVisibleChildren(at level: Int) -> Int {
		let   children = visibleChildren(at: level - 1)
		var maxVisible = 0
		
		for child in children {
			if  let  count = child.widgetZone?.visibleChildren.count,
				maxVisible < count {
				maxVisible = count
			}
		}
		
		return maxVisible
	}
	
	static func traverseAllVisibleWidgetsByLevel(_ block: IntZoneWidgetsClosure) {
		var   level = 0
		var widgets = visibleChildren(at: level)
		
		while widgets.count != 0 {
			block(level, widgets)
			
			level  += 1
			widgets = visibleChildren(at: level)
		}
	}
	
	static func visibleChildren(at level: Int) -> ZoneWidgetArray {
		var widgets = ZoneWidgetArray()
		
		for widget in gHere.visibleWidgets {
			if  widget.linesLevel == level {
				widgets.append(widget)
			}
		}
		
		return widgets
	}

}

extension WidgetHashDictionary {

	var justWidgets : ZoneWidgetArray { return ZoneWidgetArray(values) }

}
