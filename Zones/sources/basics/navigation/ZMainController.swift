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

class ZMainController: ZGesturesController {

	@IBOutlet var detailsWidth      : NSLayoutConstraint?
	@IBOutlet var hamburgerButton   : ZButton?
	@IBOutlet var searchResultsView : ZView?
	@IBOutlet var permissionView    : ZView?
	@IBOutlet var searchBoxView     : ZView?
    @IBOutlet var detailView        : ZView?
	@IBOutlet var essayView     	: ZView?
	@IBOutlet var mapView           : ZView?
    override  var controllerID      : ZControllerID { return .idMain }

	override func setup() {
		searchResultsView?.isHidden = true
		searchBoxView?    .isHidden = true
		view.gestureHandler         = self

		update()
	}

	@IBAction func hamburgerButtonAction(_ button: NSButton) {
		gShowDetailsView = detailView?.isHidden ?? true

		update()
	}

	func update() {
		hamburgerButton?.toolTip = kClickTo + gConcealmentString(for: gShowDetailsView) + " detail views"
		detailsWidth?  .constant =  gShowDetailsView ? 226.0 :  0.0
		detailView?    .isHidden = !gShowDetailsView
	}

	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
		if  gIsNoteMode {
			gEssayView?.save()
			gControllers.swapMapAndEssay(force: .wBigMapMode)
		}
	}

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		let   hideEssay = !gIsNoteMode
        let  hideSearch = !gIsSearchMode
        let hideResults = hideSearch || !(gSearchResultsController?.hasResults ?? false)

		permissionView?               .isHidden = !gIsStartupMode

		switch iKind {
			case .sFound:
				mapView?              .isHidden = !hideResults
				searchBoxView?        .isHidden =  hideSearch
				searchResultsView?    .isHidden =  hideResults
			case .sSearch:
				searchBoxView?        .isHidden =  hideSearch

				if  hideSearch {
					searchResultsView?.isHidden =  hideSearch

					assignAsFirstResponder(nil)
				}
			case .sSwap:
				gRefusesFirstResponder          = true  // prevent exit from essay from beginning an edit
				essayView? 	  	      .isHidden =  hideEssay
				mapView? 	  	      .isHidden = !hideEssay
				gRefusesFirstResponder          = false
			default: break
        }
    }

}
