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


var gSearchController: ZSearchController? { return gControllersManager.controllerForID(.search) as? ZSearchController }


class ZSearchController: ZGenericController, ZSearchFieldDelegate {


    @IBOutlet var searchBox: ZSearchField?


    override func setup() {
        super.setup()
        
        controllerID = .search
    }


    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        if  iKind == .search && gWorkMode == .searchMode {
            gSearchManager.state = .entry

            FOREGROUND(after: 0.2) {
                self.searchBox?.becomeFirstResponder()
            }
        }
    }


    func handleKeyEvent(_ event: ZEvent, with state: ZSearchState) -> ZEvent? {
        let   string = event.input
        let      key = string[string.startIndex].description
        let isReturn = key == "\r"
        let  isEntry = state == .entry
        
        if        !isReturn && isEntry {
            gSearchManager.state = .find
        } else if  isReturn && state == .find {
            if  let text = searchBoxText {
                performSearch(for: text)
            }

            return nil
        }
        
        if (isReturn && isEntry) || key == kEscape {
            endSearch()
            
            return nil
        }
        
        if key == "a" && event.modifierFlags.isCommand {
            searchBox?.selectAllText()
            
            return nil
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

    
    func performSearch(for searchString: String) {
        var combined = [ZDatabaseID: [Any]] ()
        
        for dbID in kAllDatabaseIDs {
            if  let manager = gRemoteStoresManager.cloudManager(for: dbID) {
                let  locals = manager.searchLocal(for: searchString)
                
                manager.search(for: searchString) { iObject in
                    FOREGROUND {
                        var          results = iObject as! [Any]
                        
                        results.appendUnique(contentsOf: locals) { (a, b) in
                            if  let alpha = a as? CKRecord, let beta = b as? CKRecord {
                                return alpha.recordID.recordName == beta.recordID.recordName
                            }
                            
                            return false
                        }
                        
                        let       hasResults = results.count != 0
                        gSearchManager.state = hasResults ? .list : .find
                        combined[dbID]       = results
                        self.searchBox?.text = ""
                        
                        gControllersManager.signalFor(combined as NSObject, regarding: .found)
                    }
                }
            }
        }
    }
    
    
    func control(_ control: ZControl, textView: ZTextView, doCommandBy commandSelector: Selector) -> Bool {
        let handledIt = commandSelector == Selector(("noop:"))

        if  handledIt {
            endSearch()
        }

        return handledIt
    }

}
