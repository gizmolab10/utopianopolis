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

	@IBOutlet var detailsWidth       : NSLayoutConstraint?
	@IBOutlet var hamburgerButton    : ZButton?
	@IBOutlet var essayContainerView : ZView?
	@IBOutlet var searchResultsView  : ZView?
	@IBOutlet var mapContainerView   : ZView?
	@IBOutlet var permissionView     : ZView?
	@IBOutlet var searchBoxView      : ZView?
	@IBOutlet var detailView         : ZView?
	@IBOutlet var debugView          : ZView?
    override  var controllerID       : ZControllerID { return .idMain }

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

	@IBAction func debugInfoButtonAction(_ button: NSButton) {
		if  gDebugModes.contains(.dDebugInfo) {
			gDebugModes  .remove(.dDebugInfo)
		} else {
			gDebugModes  .insert(.dDebugInfo)
		}

		update()
	}

	func update() {
		hamburgerButton?.toolTip = kClickTo + gConcealmentString(for: gShowDetailsView) + " detail views"
		detailsWidth?  .constant =  gShowDetailsView ? 226.0 :  0.0
		detailView?    .isHidden = !gShowDetailsView
		debugView?     .isHidden = !gDebugInfo || [.wSearchMode, .wEssayMode].contains(gWorkMode)
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
        let hideResults = !(gSearchResultsController?.hasResults ?? false) || hideSearch

		permissionView?               .isHidden = !gIsStartupMode

		switch iKind {
			case .sFound:
				mapContainerView?     .isHidden = !hideResults
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
				essayContainerView?   .isHidden =  hideEssay
				mapContainerView? 	  .isHidden = !hideEssay
				gRefusesFirstResponder          = false
			default: break
        }
		
		update()
    }

}
