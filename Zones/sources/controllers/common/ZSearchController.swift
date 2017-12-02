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


    @IBOutlet var    searchBox: ZSearchField?
    override  var controllerID: ZControllerID { return .searchBox }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        if kind == .search {
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
            case .ready:        exit();         return nil
            case .input: if getInput() == nil { return nil }
            default:
                break
            }
        default: if state == .ready { gSearchManager.state = .input; }
        }

        return event
    }


    func exit() {
        self.searchBox?.text = ""

        searchBox?.resignFirstResponder()
        gSearchManager.exitSearchMode()
    }


    func getInput() -> String? {
        let searchString = (searchBox?.text)!

        if ["", " ", "  "].contains(searchString) {
            exit()

            return nil
        }

        return searchString
    }


    #if os(OSX)

    func control(_ control: ZControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if  gWorkMode == .searchMode, let searchString = getInput() {
            var total = [Any] ()

            for mode in [ZStorageMode.mineMode, ZStorageMode.everyoneMode] {
                let manager = gRemoteStoresManager.cloudManagerFor(mode)

                manager.search(for: searchString) { iObject in
                    FOREGROUND {                                    // guarantee atomic ...
                        let    results = iObject as! [Any]
                        let hasResults = results.count != 0
                        let       done = total.count > 0            // ... this test must be atomic relative to each search
                        gWorkMode      = hasResults ? .searchMode : .editMode
                        total         += results

                        if done {
                            self.searchBox?.text = ""

                            gSearchManager.showResults(total)
                        }
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
            exit()
        }

        return handledIt
    }

}
