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

	override  var controllerID          : ZControllerID { return .idMain }
	@IBOutlet var alternateLeading      : NSLayoutConstraint?
	@IBOutlet var smallMapContainerView : ZView?
	@IBOutlet var essayContainerView    : ZView?
	@IBOutlet var searchResultsView     : ZView?
	@IBOutlet var mapContainerView      : ZView?
	@IBOutlet var permissionView        : ZView?
	@IBOutlet var searchBoxView         : ZView?
	@IBOutlet var detailView            : ZView?
	@IBOutlet var debugView             : ZView?
	@IBOutlet var dragView              : ZDragView?
	@IBOutlet var helpButton            : ZHelpButton?
	@IBOutlet var hamburgerButton       : ZButton?

	var hamburgerImage: ZImage? {
		var image = kHamburgerImage

		if  gIsDark {
			image = image?.invertedImage
		}

		return image
	}

	override func setup() {
		searchResultsView?.isHidden = true
		view.gestureHandler         = self

		dragView?.setup()
		update()
	}

	@IBAction func helpButtonAction(_ button: NSButton) {
		gHelpController?.show()
	}

	@IBAction func hamburgerButtonAction(_ button: NSButton) {
		gShowDetailsView = gDetailsViewIsHidden

		gSignal([.spMain, .sDetails])
	}

	func update() {
		let            showDetails = gShowDetailsView
		hamburgerButton?  .toolTip = kClickTo + gConcealmentString(for: gShowDetailsView) + " detail views"
		alternateLeading?.constant = !showDetails ? 0.0 : 226.0
		detailView?      .isHidden = !showDetails
		debugView?       .isHidden = !gDebugInfo || [.wSearchMode, .wEssayMode].contains(gWorkMode)
		hamburgerButton?    .image = hamburgerImage

		dragView?.update()
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool {         // false means not handled
		return gIsEssayMode ? false : (gMapController?.handleDragGesture(iGesture) ?? false)
	}

	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
		if  !gIsEssayMode {
			gMapController?.handleClickGesture(iGesture)
		} else if let   eView = gEssayView,
				  let gesture = iGesture {
			let      location = gesture.location(in: eView)

			if  location.x < 0.0 {				// is gesture located outside essay view?
				eView.save()
				gControllers.swapMapAndEssay(force: .wMapMode)
			}
		}
	}

    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		let   hasResults = gSearchResultsController?.hasResults ?? false
		let isSearchMode = gIsSearchMode || gIsSearchEssayMode
		let   hideSearch = !isSearchMode || gSearchResultsVisible
		let  hideResults = !isSearchMode || gIsSearchEssayMode || gIsNotSearching || gWaitingForSearchEntry || !hasResults
		let      hideMap = !hideResults  || gIsSearchEssayMode || gIsEssayMode

		switch kind {
			case .sSearch:
				if  hideSearch {
					assignAsFirstResponder(nil)
				}
			case .sSwap:
				gRefusesFirstResponder       = true          // prevent the exit from essay from beginning an edit
				essayContainerView?.isHidden = !gIsEssayMode
				gRefusesFirstResponder       = false

				dragView?.setNeedsDisplay()
			default: break
        }

		permissionView?   .isHidden = !gIsStartupMode
		mapContainerView? .isHidden =  hideMap
		searchResultsView?.isHidden =  hideResults || gIsEssayMode
		searchBoxView?    .isHidden =  hideSearch

		update()
    }

}
