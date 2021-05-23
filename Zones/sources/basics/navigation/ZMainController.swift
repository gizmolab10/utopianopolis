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

var gMainController : ZMainController? { return gControllers.controllerForID(.idMain) as? ZMainController }
var gDragView       : ZDragView?       { return gMainController?.dragView }

class ZMainController: ZGesturesController {

	@IBOutlet var detailsWidth       : NSLayoutConstraint?
	@IBOutlet var hamburgerButton    : ZButton?
	@IBOutlet var searchResultsView  : ZView?
	@IBOutlet var essayContainerView : ZView?
	@IBOutlet var mapContainerView   : ZView?
	@IBOutlet var permissionView     : ZView?
	@IBOutlet var searchBoxView      : ZView?
	@IBOutlet var detailView         : ZView?
	@IBOutlet var debugView          : ZView?
	@IBOutlet var dragView           : ZDragView?
	@IBOutlet var helpButton         : ZHelpButton?
    override  var controllerID       : ZControllerID { return .idMain }

	override func setup() {
		searchResultsView?.isHidden = true
		view.gestureHandler         = self

		update()
	}

	@IBAction func helpButtonAction(_ button: NSButton) {
		gHelpController?.show()
	}

	@IBAction func hamburgerButtonAction(_ button: NSButton) {
		gShowDetailsView = gDetailsViewIsHidden

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

		updateHamburgerImage()
	}

	func updateHamburgerImage() {
		var image = ZImage(named: "settings.jpg")

		if  gIsDark {
			image = image?.invertedImage
		}

		hamburgerButton?.image = image
	}

	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
		if  gIsEssayMode,
			let    eView = gEssayView,
			let  gesture = iGesture {
			let location = gesture.location(in: eView)

			if  location.x < 0.0 {				// is gesture located outside essay view?
				eView.save()
				gControllers.swapMapAndEssay(force: .wMapMode)
			}
		}
	}

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		let   hideEssay =  !gIsEssayMode
		let  hideSearch =  !gIsSearchMode ||   gSearching.state == .sList
        let hideResults = (!gIsSearchMode || !(gSearchResultsController?.hasResults ?? false)) && !gIsEssayMode

		permissionView?              .isHidden = !gIsStartupMode
		mapContainerView?            .isHidden = !hideResults
		searchResultsView?           .isHidden =  hideResults
		searchBoxView?               .isHidden =  hideSearch

		switch iKind {
			case .sSearch:
				if  hideSearch {
					assignAsFirstResponder(nil)
				}
			case .sSwap:
				gRefusesFirstResponder         = true          // prevent the exit from essay from beginning an edit
				essayContainerView?  .isHidden =  hideEssay
				mapContainerView?    .isHidden = !hideEssay
				gRefusesFirstResponder         = false

				dragView?.setNeedsDisplay()
				update()
			default: break
        }
    }

}
