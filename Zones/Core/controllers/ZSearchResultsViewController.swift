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


    override func identifier() -> ZControllerID { return .searchResults }


    override func handleSignal(_ iObject: Any?, kind: ZSignalKind) {
        if kind == .found {
            foundRecords = iObject as! [CKRecord]

            tableView?.reloadData()
        }
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
}
