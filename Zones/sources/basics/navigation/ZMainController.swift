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
	@IBOutlet var detailsWidth      : NSLayoutConstraint?
	@IBOutlet var swapButtonOffset  : NSLayoutConstraint?
    @IBOutlet var searchResultsView : ZView?
	@IBOutlet var permissionView    : ZView?
	@IBOutlet var searchBoxView     : ZView?
    @IBOutlet var detailView        : ZView?
	@IBOutlet var essayView     	: ZView?
	@IBOutlet var mapView           : ZView?
    override  var controllerID      : ZControllerID { return .idMain }

	override func setup() {
		searchBoxView?    .isHidden = true
		searchResultsView?.isHidden = true
	}

	@IBAction func settingsButtonAction(_ button: NSButton) {
		gShowDetailsView = detailView?.isHidden ?? true

		update()
	}

	@IBAction func chooseSkillAction(_ control: NSSegmentedControl) {
		if  let   level = ZSkillLevel(rawValue: control.selectedSegmentIndex) {
			gSkillLevel = level
		}
	}

	func update() {
		swapButtonOffset?.constant =  gShowDetailsView ?   0.0 : 35.0
		detailsWidth?    .constant =  gShowDetailsView ? 226.0 :  0.0
		detailView?      .isHidden = !gShowDetailsView

		if  gShowDetailsView {
			gDetailsController?.updateForSkillLevel()
		}
	}

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		let   hideEssay = !gIsNoteMode
        let  hideSearch = !gIsSearchMode
        let hideResults = hideSearch || !(gSearchResultsController?.hasResults ?? false)

		permissionView?.isHidden           = !gIsStartupMode
		skillControl?  .isHidden           =  false
		skillControl?.selectedSegmentIndex =  gSkillLevel.rawValue

		switch iKind {
			case .sFound:
				mapView?            .isHidden = !hideResults
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
				mapView? 	  	      .isHidden = !hideEssay
			default: break
        }
    }

}
