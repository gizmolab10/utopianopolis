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


    var widgets: [CKRecordID : ZoneWidget] = [:]


    var currentEditingWidget: ZoneWidget? {
        get { return widgetForZone(selectionManager.currentlyEditingZone) }
    }


    func clear() {
        widgets.removeAll()
    }


    func registerWidget(_ widget: ZoneWidget) {
        if let zone = widget.widgetZone, let record = zone.record {
            widgets[record.recordID] = widget
        }
    }


    func widgetForZone(_ zone: Zone?) -> ZoneWidget? {
        if let record = zone?.record {
            return widgets[record.recordID]
        }

        return nil
    }
}
