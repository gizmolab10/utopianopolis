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

class ZMainController: ZGesturesController {

	override  var controllerID       : ZControllerID { return .idMain }
	@IBOutlet var explainPopover     : ZExplanationPopover?
	@IBOutlet var alternateLeading   : NSLayoutConstraint?
	@IBOutlet var essayContainerView : ZView?
	@IBOutlet var searchResultsView  : ZView?
	@IBOutlet var permissionView     : ZView?
	@IBOutlet var searchBarView      : ZView?
	@IBOutlet var controlsView       : ZView?
	@IBOutlet var detailView         : ZView?
	@IBOutlet var debugView          : ZView?
	@IBOutlet var helpButton         : ZHelpButton?
	@IBOutlet var searchButton       : ZButton?
	@IBOutlet var dismissButton      : ZButton?
	@IBOutlet var hamburgerButton    : ZButton?
	@IBAction func helpButtonAction(_ button: NSButton) { gHelpController?.show() }

	var hamburgerImage: ZImage? {
		var image = kHamburgerImage

		if  gIsDark {
			image = image?.invertedImage
		}

		return image
	}

	override func controllerSetup(with mapView: ZMapView?) {
		searchResultsView?.isHidden = true
		view.gestureHandler         = self

		super.controllerSetup(with: mapView)
		mainUpdate()
	}

	@IBAction func hamburgerButtonAction(_ button: NSButton) {
		gShowDetailsView = gDetailsViewIsHidden

		gMapView?.removeAllTextViews(ofType: .small)
		gSignal([.spMain, .sDetails, .spRelayout])
	}

	@IBAction func searchButtonAction(_ sender: ZButton) {
		gSearching.showSearch()
	}

	@IBAction func dismissButtonAction(_ sender: ZButton) {
		gSearchBarController?.endSearch()
	}

	func searchStateDidChange() {
		searchButton? .isHidden = !gIsNotSearching
		dismissButton?.isHidden =  gIsNotSearching
	}

	func mainUpdate() {
		let            showDetails =  gShowDetailsView
		alternateLeading?.constant = !showDetails ? .zero : 226.0
		detailView?      .isHidden = !showDetails
		debugView?       .isHidden = !gDebugInfo || [.wResultsMode, .wEssayMode].contains(gWorkMode)
		controlsView?    .isHidden = !gShowMainControls
		hamburgerButton?  .toolTip =  gConcealmentString(for: gShowDetailsView) + " detail views"
		hamburgerButton?    .image =  hamburgerImage
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool {         // false means not handled
		if  gIgnoreEvents {
			return true
		}

		return gIsEssayMode ? false : (gMapController?.handleDragGesture(iGesture) ?? false)
	}

	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
		if  !gIgnoreEvents {
			if  !gIsEssayMode {
				gMapController?.handleClickGesture(iGesture)
			} else if let eView = gEssayView,
				let gesture = iGesture {
				let      location = gesture.location(in: eView)

				if  location.x < .zero {				// is gesture located outside essay view?
					eView.save()
					gControllers.swapMapAndEssay(force: .wMapMode) {
						gMapController?.handleClickGesture(iGesture)
					}
				}
			}
		}
	}

    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		switch kind {
			case .sSearch:
				assignAsFirstResponder(gIsNotSearching ? nil : gSearchBarController?.searchBar)
			case .sSwap:
				gRefusesFirstResponder       = true          // prevent the exit from essay from beginning an edit
				essayContainerView?.isHidden = !gIsEssayMode
				gRefusesFirstResponder       = false

				gMapController?.setNeedsDisplay()
			default: break
        }

		permissionView?   .isHidden = !gIsStartupMode
		searchBarView?    .isHidden =  gIsNotSearching || (gSearchResultsVisible && gSearchResultsController?.hasResults ?? false)
		searchResultsView?.isHidden =  gIsNotSearching || gWaitingForSearchEntry || gIsEssayMode

		mainUpdate()
    }

}
