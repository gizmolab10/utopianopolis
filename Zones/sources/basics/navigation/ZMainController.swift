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

	@IBOutlet var alternateLeading   : NSLayoutConstraint?
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

	var hamburgerImage: ZImage? {
		var image = ZImage(named: "settings.jpg")

		if  gIsDark {
			image = image?.invertedImage
		}

		return image
	}

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

		gSignal([.spMain, .sDetails])
	}

	@IBAction func debugInfoButtonAction(_ button: NSButton) {
		if  gDebugModes.contains(.dDebugInfo) {
			gDebugModes  .remove(.dDebugInfo)
		} else {
			gDebugModes  .insert(.dDebugInfo)
		}

		gSignal([.spMain])
	}

	func update() {
		let            showDetails = gShowDetailsView
		hamburgerButton?  .toolTip = kClickTo + gConcealmentString(for: gShowDetailsView) + " detail views"
		alternateLeading?.constant = !showDetails ? 0.0 : 226.0
		detailView?      .isHidden = !showDetails
		debugView?       .isHidden = !gDebugInfo || [.wSearchMode, .wEssayMode].contains(gWorkMode)
		hamburgerButton?    .image = hamburgerImage
	}

	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
		if  gIsEssayMode,
			let    eView = gEssayView,
			let  gesture = iGesture {
			let location = gesture.location(in: eView)

			if  location.x < 0.0 {				// is gesture located outside essay view?
				eView.save()
				gMainController?.swapMapAndEssay(force: .wMapMode)
			}
		}
	}

	func swapMapAndEssay(force mode: ZWorkMode? = nil) {
		FOREGROUND { 	                                // avoid infinite recursion (generic menu handler invoking map editor's handle key)
			gTextEditor.stopCurrentEdit()
			gEssayView?.setControlBarButtons(enabled: gWorkMode == .wEssayMode)

			gWorkMode                         =  gIsEssayMode ? .wMapMode : .wEssayMode
			gRefusesFirstResponder            =  true          // prevent the exit from essay from beginning an edit
			self.essayContainerView?.isHidden = !gIsEssayMode
			gRefusesFirstResponder            =  false

			self.dragView?.setNeedsDisplay()
			gSignal([.sData, .spCrumbs, .spSmallMap, .sRelayout])
		}
	}

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		let   hasResults = gSearchResultsController?.hasResults ?? false
		let isSearchMode = gIsSearchMode || gIsSearchEssayMode
		let   hideSearch = !isSearchMode || gSearchResultsVisible
		let  hideResults = !isSearchMode || gIsSearchEssayMode || !hasResults || gWaitingForSearchEntry || gIsNotSearching

		switch iKind {
			case .sSearch:
				if  hideSearch {
					assignAsFirstResponder(nil)
				}
			default: break
        }

		permissionView?            .isHidden = !gIsStartupMode
		mapContainerView?          .isHidden = !hideResults || gIsEssayMode || gIsSearchEssayMode
		searchResultsView?         .isHidden =  hideResults || gIsEssayMode
		searchBoxView?             .isHidden =  hideSearch

		update()
    }

}
