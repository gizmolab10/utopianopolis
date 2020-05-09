//
//  ZMainController.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

var gMainController: ZMainController? { return gControllers.controllerForID(.idMain) as? ZMainController }

class ZMainController: ZGenericController {

	@IBOutlet var skillControl      : NSSegmentedControl?
    @IBOutlet var searchResultsView : ZView?
    @IBOutlet var searchBoxView     : ZView?
    @IBOutlet var detailView        : ZView?
	@IBOutlet var graphView         : ZView?
	@IBOutlet var essayView     	: ZView?
    override  var controllerID      : ZControllerID { return .idMain }

	override func setup() {
		searchBoxView?    .isHidden = true
		searchResultsView?.isHidden = true
	}

	@IBAction func skillAction(_ control: NSSegmentedControl) {
		if  let   level = ZSkillLevel(rawValue: control.selectedSegmentIndex) {
			gSkillLevel = level
		}
	}

	func updateForSkillLevel() {
		detailView?.isHidden = gUnclutteredSkillLevel

		gDetailsController?.updateForSkillLevel()
	}

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		let   hideEssay = !gIsNoteMode
        let  hideSearch = !gIsSearchMode
        let hideResults = hideSearch || !(gSearchResultsController?.hasResults ?? false)

		skillControl?.selectedSegmentIndex = gSkillLevel.rawValue
		skillControl?.isHidden             = false

		switch iKind {
			case .sFound:
				graphView?            .isHidden = !hideResults
				searchBoxView?        .isHidden =  hideSearch
				searchResultsView?    .isHidden =  hideResults
			case .sSearch:
				searchBoxView?        .isHidden =  hideSearch

				if  hideSearch {
					searchResultsView?.isHidden =  hideSearch

					assignAsFirstResponder(nil)
				}
			case .sSwap:
				essayView? 	  	      .isHidden =  hideEssay
				graphView? 	  	      .isHidden = !hideEssay
			default: break
        }
    }

}
