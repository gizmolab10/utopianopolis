//
//  ZSearchController.swift
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


class ZSearchController: ZGenericController, ZSearchFieldDelegate {


    @IBOutlet var searchBox: ZSearchField?
    

    override func identifier() -> ZControllerID { return .searchBox }


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        if kind == .search {
            if gShowsSearching {
                assignAsFirstResponder(searchBox!)
            }
        }
    }


    func endSearching() {
        gShowsSearching = false

        signalFor(nil, regarding: .search)
    }


    #if os(OSX)
    func searchFieldDidEndSearching(_ sender: NSSearchField) {
        endSearching()
    }


    func control(_ control: ZControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        performance(searchBox?.text)
        searchBox?.resignFirstResponder()

        let find = (searchBox?.text)!

        if find == "" {
            endSearching()
        } else {
            gCloudManager.searchFor(find, storageMode: gStorageMode) { iObject in
                let hasResults = ((iObject as? [Any])?.count)! != 0
                gWorkMode       = hasResults && gShowsSearching ? .searchMode : .editMode

                if hasResults {
                    self.dispatchAsyncInForeground {
                        self.searchBox?.text = ""

                        self.signalFor(iObject, regarding: .found)
                    }
                }
            }
        }

        return true
    }
    #endif

    
    func control(_ control: ZControl, textView: ZTextView, doCommandBy commandSelector: Selector) -> Bool {
        let handledIt = commandSelector == Selector(("noop:"))

        if  handledIt {
            gWorkMode       = .editMode
            gShowsSearching = false

            signalFor(nil, regarding: .found)
            signalFor(nil, regarding: .search)
        }

        return handledIt
    }

}
