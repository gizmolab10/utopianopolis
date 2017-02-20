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
    var   resultsAreVisible = false
    var        foundRecords = [CKRecord] ()
    var             monitor: Any?


    override func identifier() -> ZControllerID { return .searchResults }


    override func handleSignal(_ iObject: Any?, kind: ZSignalKind) {
        if kind == .found {
            resultsAreVisible = false
            
            if gShowsSearching, let records = iObject as? [CKRecord] {
                let count = records.count

                if count == 1 {
                    self.resolveRecord(records[0])
                } else if count > 0 {
                    foundRecords = records

                    sortRecords()
                    tableView?.reloadData()
                    monitorKeyEvents()

                    #if os(OSX)
                    dispatchAsyncInForeground {
                        self.assignAsFirstResponder(self.tableView)
                        self.tableView?.selectRowIndexes(NSIndexSet(index: 0) as IndexSet, byExtendingSelection: false)
                    }
                    #endif
                }
            } else {
                removeMonitorAsync()
            }
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


    #if os(OSX)

    func numberOfRows(in tableView: ZTableView) -> Int {
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

    #else


    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return foundRecords.count
    }


    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }


    #endif


    func resolve() -> Bool {
        #if os(iOS)
            return false
        #else

        let    index = self.tableView?.selectedRow
        let resolved = index != -1

        if resolved {
            let record = self.foundRecords[index!]

            resolveRecord(record)
        }

        return resolved

        #endif
    }


    func resolveRecord(_ record: CKRecord) {
        var zone = gCloudManager.zoneForRecordID(record.recordID)

        if zone == nil {
            zone = Zone(record: record, storageMode: gStorageMode)

            zone?.needChildren()
        }

        gHere = zone!

        clear()
        zone?.grab()
        signalFor(nil, regarding: .redraw)
    }


    func clear() {
        resultsAreVisible = false
        gShowsSearching    = false
        gWorkMode          = .editMode

        self.signalFor(nil, regarding: .search)
        self.signalFor(nil, regarding: .found)
    }


    func reset() {
        if  resultsAreVisible || foundRecords.count == 0 {
            clear()
        } else {
            resultsAreVisible = true

            signalFor(nil, regarding: .search)
        }

        removeMonitorAsync()
    }


    func monitorKeyEvents() {
        #if os(OSX)
            if  monitor == nil {
                monitor        = ZEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) -> ZEvent? in
                    let string = event.input
                    let    key = string[string.startIndex].description

                    if !event.modifierFlags.isNumericPad {
                        switch key {
                        case    "f":    self.reset();    return nil
                        case   "\r": if self.resolve() { return nil }; break
                        default:                         break
                        }
                    } else if let arrow = key.arrow {
                        switch arrow {
                        case  .left:    self.clear();    return nil
                        case .right: if self.resolve() { return nil }; break
                        default:                         break
                        }
                    }

                    return event
                }
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
