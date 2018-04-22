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


    override func setup() {
        super.setup()
        
        controllerID = .searchBox
    }


    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        if iKind == .search {
            if  gWorkMode == .searchMode {
                assignAsFirstResponder(searchBox!)

                gSearchManager.state = .ready
            }
        }
    }


    func handleKeyEvent(_ event: ZEvent, with state: ZSearchState) -> ZEvent? {
        let string = event.input
        let    key = string[string.startIndex].description

        switch key {
        case "\r":
            switch state {
            case .ready: endSearch();               return nil
            case .input: if searchBoxText == nil { return nil }
            default:
                break
            }
        default: if state == .ready { gSearchManager.state = .input; }
        }

        return event
    }


    func endSearch() {
        self.searchBox?.text = ""

        searchBox?.resignFirstResponder()
        gSearchManager.exitSearchMode()
    }


    var searchBoxText: String? {
        let searchString = (searchBox?.text)!

        if ["", " ", "  "].contains(searchString) {
            endSearch()

            return nil
        }

        return searchString
    }


    #if os(OSX)

    func control(_ control: ZControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if  gWorkMode   == .searchMode, let searchString = searchBoxText {
            var combined = [ZDatabaseID: [Any]] ()

            for dbID in kAllDatabaseIDs {
                let manager = gRemoteStoresManager.cloudManagerFor(dbID)
                let  locals = manager.searchLocal(for: searchString)

                manager.search(for: searchString) { iObject in
                    FOREGROUND {
                        var          results = iObject as! [Any]

                        results.appendUnique(contentsOf: locals)

                        let       hasResults = results.count != 0
                        gWorkMode            = hasResults ? .searchMode : .graphMode
                        combined[dbID]       = results
                        self.searchBox?.text = ""

                        gSearchManager.showResults(combined)
                    }
                }
            }
        }

        return true
    }

    #endif

    
    func control(_ control: ZControl, textView: ZTextView, doCommandBy commandSelector: Selector) -> Bool {
        let handledIt = commandSelector == Selector(("noop:"))

        if  handledIt { // && gSearchManager.state != .browse {
            endSearch()
        }

        return handledIt
    }

}
