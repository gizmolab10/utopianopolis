//
//  ZSearchController.swift
//  Thoughtful
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


var gSearchController: ZSearchController? { return gControllers.controllerForID(.search) as? ZSearchController }


class ZSearchController: ZGenericController, ZSearchFieldDelegate {


    @IBOutlet var searchBox: ZSearchField?
    override  var controllerID: ZControllerID { return .search }


    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        if  iKind == .eSearch && gWorkMode == .searchMode {
            gSearching.state = .entry

            FOREGROUND(after: 0.2) {
                self.searchBox?.becomeFirstResponder()
            }
        }
    }


    func handleEvent(_ event: ZEvent) -> ZEvent? {
        let   string = event.input ?? ""
        let    flags = event.modifierFlags
        let  COMMAND = flags.isCommand
        let      key = string[string.startIndex].description
        let isReturn = key == "\r"
        let    state = gSearching.state
        let  isEntry = state == .entry
        
        if        !isReturn && isEntry {
            gSearching.state = .find
        } else if  isReturn {
            if  gSearching.state == .list {
                searchBox?.becomeFirstResponder()
            } else if  let text = searchBoxText {
                performSearch(for: text)
            }

            return nil
        }
        
        if (isReturn && isEntry) || key == kEscape || (key == "f" && COMMAND) {
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
        searchBox?.resignFirstResponder()
        gSearching.exitSearchMode()
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
        var remaining = kAllDatabaseIDs.count
        
        for cloud in gRemoteStorage.allClouds {
            let  locals = cloud.searchLocal(for: searchString)
            
            cloud.search(for: searchString) { iObject in
                FOREGROUND {
                    var results = iObject as! [Any]
                    remaining -= 1
                    
                    results.appendUnique(contentsOf: locals) { (a, b) in
                        if  let alpha = a as? CKRecord,
                            let  beta = b as? CKRecord {
                            return alpha.recordID.recordName == beta.recordID.recordName
                        }
                        
                        return false
                    }
                    
                    combined[cloud.databaseID] = results
                    
                    if  remaining == 0 {
                        gSearchResultsController?.foundRecords = combined as? [ZDatabaseID: [CKRecord]] ?? [:]
                        gSearching.state = (gSearchResultsController?.hasResults ?? false) ? .list : .find
                        
                        gControllers.signalFor(nil, regarding: .eFound)
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
