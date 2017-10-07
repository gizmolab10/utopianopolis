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


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
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
        performance(searchBox?.text)

        if  let searchString = getInput() {
            gCloudManager.search(for: searchString) { iObject in
                let hasResults = (iObject as! [Any]).count != 0
                gWorkMode      = hasResults ? .searchMode : .editMode

                if hasResults {
                    self.FOREGROUND {
                        self.searchBox?.text = ""

                        gSearchManager.showResults(iObject)
                    }
                }
            }
        }

        return true
    }

    #endif

    
    func control(_ control: ZControl, textView: ZTextView, doCommandBy commandSelector: Selector) -> Bool {
        let handledIt = commandSelector == Selector(("noop:"))

        if  handledIt && gSearchManager.state != .browse {
            exit()
        }

        return handledIt
    }

}
