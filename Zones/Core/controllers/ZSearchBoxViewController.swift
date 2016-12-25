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


    @IBOutlet var searchBox: ZSearchField?
    

    override func identifier() -> ZControllerID { return .searchBox }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        if kind == .search {
            if showsSearching {
                mainWindow.makeFirstResponder(searchBox!)
            }
        }
    }


    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        report(searchBox?.text)
        searchBox?.resignFirstResponder()

        let find = (searchBox?.text)!

        if find == "" {
            showsSearching = false

            signal(nil, regarding: .search)
        } else {
            cloudManager.searchFor(find) { iObject in
                let hasResults = ((iObject as? [Any])?.count)! != 0
                workMode       = hasResults && showsSearching ? .searchMode : .editMode

                if hasResults {
                    self.searchBox?.text = ""

                    self.signal(iObject, regarding: .found)
                }
            }
        }

        return true
    }


    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let handledIt = commandSelector == Selector(("noop:"))

        if  handledIt {
            workMode       = .editMode
            showsSearching = false

            signal(nil, regarding: .search)
        }

        return handledIt
    }

}
