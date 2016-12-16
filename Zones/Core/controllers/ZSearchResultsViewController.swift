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


class ZSearchResultsViewController: ZGenericViewController {


    @IBOutlet var searchBox: NSSearchField?
    var foundRecords: [CKRecord] = []
    

    override func identifier() -> ZControllerID { return .searchResults }


    override func handleSignal(_ iObject: Any?, kind: ZSignalKind) {
        if kind == .found {

            foundRecords = iObject as! [CKRecord]

            self.report(foundRecords)
        }
    }

}
