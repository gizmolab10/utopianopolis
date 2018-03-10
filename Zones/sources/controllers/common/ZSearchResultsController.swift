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
    var           foundRecords = [ZDatabaseID: [CKRecord]] ()
    var                monitor: Any?
    var       searchController: ZSearchController? { return gControllersManager.controllerForID(.searchBox) as? ZSearchController }
    @IBOutlet var    tableView: ZTableView?


    override func setup() {
        controllerID = .searchResults
    }


    var foundRecordsCount: Int {
        var count = 0

        for records in foundRecords.values {
            count += records.count
        }

        return count
    }


    // MARK:- content
    // MARK:-


    override func handleSignal(_ iObject: Any?, iKind: ZSignalKind) {
        if iKind == .found {
            resultsAreVisible = false
            
            if  gWorkMode == .searchMode, let recordsByDatabaseID = iObject as? [ZDatabaseID: [CKRecord]] {
                foundRecords = recordsByDatabaseID

                for (dbID, records) in recordsByDatabaseID {
                    let count = records.count

                    if count == 1 {
                        self.resolveRecord(dbID, records[0])
                    } else if count > 0 {

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
    }


    func sortRecords() {
        for (mode, records) in foundRecords {
            foundRecords[mode] = records.sorted() {
                if  let a = $0[kpZoneName] as? String,
                    let b = $1[kpZoneName] as? String {
                    return a.lowercased() < b.lowercased()
                }

                return false
            }
        }
    }


    // MARK:- delegate
    // MARK:-


    #if os(OSX)

    func numberOfRows(in tableView: ZTableView) -> Int { return foundRecordsCount }


    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        var object = ""

        if  let (dbID, record) = identifierAndRecord(at: row) {

            if let zone = gRemoteStoresManager.cloudManagerFor(dbID).maybeZoneForRecordID(record.recordID) {
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


    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int            { return foundRecordsCount }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell { return UITableViewCell() }


    #endif


    // MARK:- user feel
    // MARK:-


    func identifierAndRecord(at iIndex: Int) -> (ZDatabaseID, CKRecord)? {
        var index = iIndex
        var count = 0

        for (mode, records) in foundRecords {
            index -= count
            count  = records.count

            if count > index {
                return (mode, records[index])
            }
        }

        return nil
    }


    @discardableResult func resolve() -> Bool {
        var resolved = false

        #if os(OSX)
            if  gWorkMode         == .searchMode,
                let          index = self.tableView?.selectedRow,
                index             != -1,
                let (dbID, record) = identifierAndRecord(at: index) {
                resolved           = true

                resolveRecord(dbID, record)
            }
        #endif

        return resolved
    }


    func resolveRecord(_ dbID: ZDatabaseID, _ record: CKRecord) {
        gDatabaseID = dbID
        var zone    = gCloudManager.maybeZoneForRecordID(record.recordID)

        if  zone   == nil {
            zone    = Zone(record: record, databaseID: dbID)
        }

        gHere       = zone!

        clear()
        zone?.grab()
        zone?.needChildren()
        zone?.revealChildren()
        signalFor(nil, regarding: .redraw)

        gBatchManager.sync { iSame in
            self.signalFor(nil, regarding: .redraw)
        }
    }


    func clear() {
        resultsAreVisible = false
        gWorkMode         = .graphMode

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
