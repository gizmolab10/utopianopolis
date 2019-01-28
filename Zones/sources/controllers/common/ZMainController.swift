//
//  ZMainController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


var gMainController: ZMainController? { return gControllers.controllerForID(.main) as? ZMainController }


class ZMainController: ZGenericController {


    @IBOutlet var detailsWidth:        NSLayoutConstraint?
    @IBOutlet var searchBoxHeight:     NSLayoutConstraint?
    @IBOutlet var searchResultsView:   ZView?
    @IBOutlet var searchBoxView:       ZView?
    @IBOutlet var detailView:          ZView?
    @IBOutlet var editorView:          ZView?
    @IBOutlet var browsingModeLabel:   ZTextField?
    @IBOutlet var insertionModeLabel:  ZTextField?
    @IBOutlet var browsingModeButton:  ZTriangleButton?
    @IBOutlet var insertionModeButton: ZTriangleButton?
    override  var controllerID:        ZControllerID { return .main }


    override func setup() {
        searchBoxView?    .isHidden = true
        searchResultsView?.isHidden = true
        
        updateModeInformation()
    }


    @IBAction func insertionModeButtonAction(sender: ZButton) {
        gInsertionMode = gInsertionsFollow ? .precede : .follow
        
        gControllers.signalFor(nil, multiple: [.ePreferences, .eMain])
    }
    
    
    @IBAction func browsingModeButtonAction(sender: ZButton) {
        gBrowsingMode = gBrowsingIsConfined ? .cousinJumps : .confined
        
        gControllers.signalFor(nil, multiple: [.ePreferences, .eMain])
    }
    

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        let  hideSearch = gWorkMode != .searchMode
        let hideResults = hideSearch || !(gSearchResultsController?.hasResults ?? false)

        switch iKind {
        case .eFound:
            searchBoxView?        .isHidden = hideSearch
            searchResultsView?    .isHidden = hideResults
        case .eSearch:
            searchBoxView?        .isHidden = hideSearch

            if  hideSearch {
                searchResultsView?.isHidden = hideSearch

                assignAsFirstResponder(nil)
            }
        default:
            updateModeInformation()
        }
    }

    
    func updateModeInformation() {
        insertionModeButton?.setState(gInsertionsFollow)
        browsingModeButton? .setState(!gBrowsingIsConfined)
        insertionModeLabel?.text = "new ideas " + (gInsertionsFollow ? "follow" : "precede")
        browsingModeLabel? .text = "vertical browsing " + (gBrowsingIsConfined ? "is confined to" : "can jump outside") + " siblings"
    }
    
}
