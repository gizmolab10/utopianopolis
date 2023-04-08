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

func gInBackgroundWhileShowingBusy(_ closure: @escaping Closure) { gMainController?.inBackgroundWhileShowingBusy(closure) }
func           gShowAppIsBusyWhile(_ closure: @escaping Closure) { gMainController?.showAppIsBusyWhile          (closure) }
var            gMainController : ZMainController?                { return gControllers.controllerForID(.idMain) as? ZMainController }

class ZMainController: ZGesturesController {

	override  var controllerID               : ZControllerID { return .idMain }
	@IBOutlet var explainPopover             : ZExplanationPopover?
	@IBOutlet var alternateLeading           : NSLayoutConstraint?
	@IBOutlet var searchOptionsContainerView : ZView?
	@IBOutlet var essayContainerView         : ZView?
	@IBOutlet var searchResultsView          : ZView?
	@IBOutlet var permissionView             : ZView?
	@IBOutlet var experimentView             : ZView?
	@IBOutlet var searchBarView              : ZView?
	@IBOutlet var controlsView               : ZView?
	@IBOutlet var detailView                 : ZView?
	@IBOutlet var debugView                  : ZView?
	@IBOutlet var searchButton               : ZButton?
	@IBOutlet var dismissButton              : ZButton?
	@IBOutlet var hamburgerButton            : ZButton?
	@IBOutlet var helpButton                 : ZHelpButton?
	@IBOutlet var spinner                    : ZProgressIndicator?
	var           shownBusyDepth             = 0

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

	func mainUpdate() {
		let            showDetails =  gShowDetailsView
		alternateLeading?.constant = !showDetails ? .zero : 226.0
		detailView?      .isHidden = !showDetails
		debugView?       .isHidden = !gDebugInfo || [.wResultsMode, .wEssayMode].contains(gWorkMode)
		controlsView?    .isHidden = !gShowMainControls
		hamburgerButton?  .toolTip =  gConcealmentString(hide: gShowDetailsView) + " detail views"
		hamburgerButton?    .image =  hamburgerImage
	}

	// MARK: - search
	// MARK: -

	@IBAction func searchButtonAction(_ sender: ZButton) {
		gSearching.showSearch()
		searchStateDidChange()
	}

	@IBAction func dismissButtonAction(_ sender: ZButton) {
		gSearchBarController?.endSearch()
		searchStateDidChange()
	}

	func searchStateDidChange() {
		searchOptionsContainerView?.isHidden =  gIsNotSearching
		dismissButton?             .isHidden =  gIsNotSearching
		searchButton?              .isHidden = !gIsNotSearching
	}

	// MARK: - help, settings, drag and signal
	// MARK: -

	@IBAction func      helpButtonAction(_ button: NSButton) { gHelpController?.show() }
	@IBAction func hamburgerButtonAction(_ button: NSButton) {
		gShowDetailsView = gDetailsViewIsHidden

		gTextEditor.stopCurrentEdit()
		gMapView?.removeAllTextViews(ofType: .favorites)
		gSignal([.spMain, .sDetails, .spRelayout])
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool {         // false means not handled
		if  gIgnoreEvents {
			return true
		}

		return gIsEssayMode ? false : (gMapController?.handleDragGesture(iGesture) ?? false)
	}

	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
		if  let         gesture = iGesture, !gIgnoreEvents {
			if  !gIsEssayMode {
				gMapController?.handleClickGesture(iGesture)
			} else if let eView = gEssayView {
				let    location = gesture.location(in: eView)

				if  location.x < .zero {				// is gesture located outside essay view?
					eView.save()
					gControllers.swapMapAndEssay(force: .wMapMode) {
						gMapController?.handleClickGesture(iGesture)
					}
				}
			}
		}
	}

    override func handleSignal(kind: ZSignalKind) {
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

		let        hasSearchResults = gSearchResultsController?.hasResults ?? false
		permissionView?   .isHidden = !gIsStartupMode
		searchBarView?    .isHidden =  gIsNotSearching || (hasSearchResults && gSearchStateIsList)
		searchResultsView?.isHidden =  gIsNotSearching || !hasSearchResults || gIsEssayMode

		mainUpdate()
    }

	// MARK: - spinner
	// MARK: -

	func showAppIsBusy(_ start: Bool) {
		if  let spinner = gMainController?.spinner {
			if  start {
				if  shownBusyDepth == 0 {
					gRefusesFirstResponder = true

					spinner.startAnimating()
				}

				shownBusyDepth += 1
			} else {
				shownBusyDepth -= 1

				if  shownBusyDepth == 0 {
					spinner.stopAnimating()

					gRefusesFirstResponder = false
				}
			}
		}
	}

	func showAppIsBusyWhile(_ closure: @escaping Closure) {
		FOREGROUND {
			self.showAppIsBusy(true)
			closure()
			self.showAppIsBusy(false)
		}
	}

	func inBackgroundWhileShowingBusy(_ closure: @escaping Closure) {
		FOREGROUND {
			self.showAppIsBusy(true)

			BACKGROUND {
				closure()

				FOREGROUND {
					self.showAppIsBusy(false)
				}
			}
		}
	}

}
