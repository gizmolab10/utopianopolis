//
//  ZSearchBoxViewController.swift
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


class ZSearchBoxViewController: ZGenericViewController, ZSearchFieldDelegate {


    @IBOutlet var searchBox: ZoneSearchField?
    

    override func identifier() -> ZControllerID { return .searchBox }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        if kind == .search {
            if showsSearching {
                mainWindow?.makeFirstResponder(searchBox!)
            }
        }
    }


    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        report(searchBox?.text)
        searchBox?.resignFirstResponder()

        let find = (searchBox?.text)!

        if find == "" {
            controllersManager.signal(nil, regarding: .search)
        } else {
            cloudManager.searchFor(find) { iObject in
                controllersManager.signal(iObject, regarding: .found)
            }
        }

        return true
    }

}
