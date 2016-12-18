//
//  ZSearchResultsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 12/15/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZSearchResultsViewController: ZGenericViewController, ZTableViewDataSource, ZTableViewDelegate {


    @IBOutlet var tableView: ZTableView?
    var        foundRecords: [CKRecord] = []
    var             monitor: Any?


    override func identifier() -> ZControllerID { return .searchResults }


    override func handleSignal(_ iObject: Any?, kind: ZSignalKind) {
        if kind == .found, let records = iObject as? [CKRecord] {
            foundRecords = records

            sortRecords()
            tableView?.reloadData()
            monitorKeyEvents()
        } else {
            removeMonitorAsync()
        }
    }


    func sortRecords() {
        let records = foundRecords.map { $0 } // a copy, so that while enumerating it, elements can be removed from original

        for record in records {
            if record["parent"] == nil {
                foundRecords.remove(at: foundRecords.index(of: record)!)
            }
        }

        foundRecords.sort(by: {
            let a = $0[zoneNameKey] as! String
            let b = $1[zoneNameKey] as! String

            return a.lowercased() < b.lowercased()
        })
    }

    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return foundRecords.count
    }


    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        var object = ""

        if row < foundRecords.count {
            let record = foundRecords[row]
            object     = record[zoneNameKey] as! String
        }

        return object
    }


    func resolveRecord(_ record: CKRecord) {
        var zone = cloudManager.zoneForRecordID(record.recordID)

        if zone == nil {
            zone = Zone(record: record, storageMode: travelManager.storageMode)

            zone?.needChildren()
        }

        travelManager.hereZone = zone

        selectionManager.grab(zone)
        controllersManager.signal(nil, regarding: .data)
    }


    func monitorKeyEvents() {
        #if os(OSX)
            if monitor == nil {
                monitor = ZEvent.addLocalMonitorForEvents(matching: .keyDown, handler: {(event) -> ZEvent? in
                    if  let  string = event.charactersIgnoringModifiers {
                        let     key = string[string.startIndex].description
                        let   flags = event.modifierFlags
                        let isArrow = flags.contains(.numericPad) && flags.contains(.function)

                        if isArrow {
                            let arrow = ZArrowKey(rawValue: key.utf8CString[2])!

                            if arrow == .right {
                                let  index = self.tableView?.selectedRow

                                if index != -1 {
                                    let     record = self.foundRecords[index!]
                                    showsSearching = false
                                    workMode       = .edit

                                    controllersManager.signal(nil, regarding: .search)
                                    controllersManager.signal(nil, regarding: .found)
                                    self.resolveRecord(record)
                                }
                            }
                        }
                    }

                    return event
                })
            }
        #endif
    }


    func removeMonitorAsync() {
        #if os(OSX)
            if let save = monitor {
                monitor = nil

                dispatchAsyncInForegroundAfter(0.001, closure: {
                    ZEvent.removeMonitor(save)
                })
            }
        #endif
    }
    
}
