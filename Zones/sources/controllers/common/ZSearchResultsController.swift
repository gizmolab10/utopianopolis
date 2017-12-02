//
//  ZSearchResultsController.swift
//  Zones
//
//  Created by Jonathan Sand on 12/15/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZSearchResultsController: ZGenericController, ZTableViewDataSource, ZTableViewDelegate {


    var      resultsAreVisible = false
    var            inSearchBox = false
    var           foundRecords = [CKRecord] ()
    var                monitor: Any?
    override  var controllerID: ZControllerID      { return .searchResults }
    var       searchController: ZSearchController? { return gControllersManager.controllerForID(.searchBox) as? ZSearchController }
    @IBOutlet var    tableView: ZTableView?


    // MARK:- content
    // MARK:-


    override func handleSignal(_ iObject: Any?, kind: ZSignalKind) {
        if kind == .found {
            resultsAreVisible = false
            
            if  gWorkMode == .searchMode, let records = iObject as? [CKRecord] {
                let count = records.count

                if count == 1 {
                    self.resolveRecord(records[0])
                } else if count > 0 {
                    foundRecords = records

                    sortRecords()
                    tableView?.reloadData()

                    #if os(OSX)
                    FOREGROUND {
                        self.tableView?.selectRowIndexes(NSIndexSet(index: 0) as IndexSet, byExtendingSelection: false)
                    }
                    #endif
                }
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
            let a = $0[gZoneNameKey] as! String
            let b = $1[gZoneNameKey] as! String

            return a.lowercased() < b.lowercased()
        })
    }


    // MARK:- delegate
    // MARK:-


    #if os(OSX)

    func numberOfRows(in tableView: ZTableView) -> Int {
        return foundRecords.count
    }


    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        var      object = ""

        if row < foundRecords.count {
            let  record = foundRecords[row]

            if let zone = gCloudManager.zoneForRecordID(record.recordID) {
                object  =   zone.decoratedName
            } else {
                object  = record.decoratedName
            }

            if row == tableView.selectedRow {
                object = "• \(object)"
            }
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


    // MARK:- user feel
    // MARK:-


    @discardableResult func resolve() -> Bool {
        var resolved = false

        #if os(OSX)
            if  gWorkMode == .searchMode {
                let index = self.tableView?.selectedRow
                resolved  = index != -1

                if  resolved {
                    let record = self.foundRecords[index!]

                    resolveRecord(record)
                }
            }
        #endif

        return resolved
    }


    func resolveRecord(_ record: CKRecord) {
        var zone  = gCloudManager.zoneForRecordID(record.recordID)

        if  zone == nil {
            zone  = Zone(record: record, storageMode: gStorageMode)
        }

        gHere = zone!

        clear()
        zone?.grab()
        zone?.needChildren()
        zone?.displayChildren()
        signalFor(nil, regarding: .redraw)

        gDBOperationsManager.sync {
            self.signalFor(nil, regarding: .redraw)
        }
    }


    func clear() {
        resultsAreVisible = false
        gWorkMode         = .editMode

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
    }


    func moveSelection(up: Bool, extreme: Bool) {
        if  let             t = tableView {
            var           row = t.selectedRow
            let       maximum = t.numberOfRows - 1

            if extreme {
                row           = up ?  0 : maximum
            } else {
                row          += up ? -1 : 1

                if  row       > maximum {
                    row       = 0
                } else if row < 0 {
                    row       = maximum
                }
            }

            let rows = [row] as IndexSet

            t.selectRowIndexes(rows, byExtendingSelection: false) // (, byExtendingSelection: false)
        }
    }


    // MARK:-


    func handleBrowseKeyEvent(_ event: ZEvent) -> ZEvent? {
        let       string = event.input
        let        flags = event.modifierFlags
        let    isCommand = flags.isCommand
        let          key = string[string.startIndex].description

        if  let    arrow = key.arrow {
            switch arrow {
            case    .up:    moveSelection(up: true,  extreme: isCommand)
            case  .down:    moveSelection(up: false, extreme: isCommand)
            case  .left:    clear();    return nil
            case .right: if resolve() { return nil }; break
            }
        } else if    key == "\r", // N.B. test key first since getInput has a possible side-effect of exiting search
            let        s  = searchController,
            s.getInput() == nil {
            clear()
            resolve()

            return nil
        }

        return event
    }

}
