//
//  ZControlsController.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/22/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

var gControlsController: ZControlsController? { return gControllers.controllerForID(.idControls) as? ZControlsController }

class ZControlsController: ZGenericController {

	override  var controllerID        : ZControllerID { return .idControls }
	@IBOutlet var mapControlsView     : ZMapControlsView?
	@IBOutlet var searchScopeControl  : ZSegmentedControl?
	@IBOutlet var searchFilterControl : ZSegmentedControl?
	@IBOutlet var searchOptionsView   : ZView?
	@IBOutlet var dismissButton       : ZButton?
	@IBOutlet var searchButton        : ZButton?

	@IBAction func search(_ sender: ZButton) { gSearching.showSearch() }
	func updateOptionView() { stateDidChange() }

	override func controllerSetup(with mapView: ZMapView?) {
		searchOptionsView?.zlayer.backgroundColor = kWhiteColor.cgColor

		stateDidChange()
	}

	override func handleSignal(_ iSignalObject: Any?, kind: ZSignalKind) {
		mapControlsView?.setupAndRedraw()
		filterDidChange()
		scopeDidChange()
		stateDidChange()
	}

	func stateDidChange() {
		searchOptionsView?.isHidden =  gIsNotSearching || gIsSearchEssayMode
		dismissButton?    .isHidden =  gIsNotSearching
		searchButton?     .isHidden = !gIsNotSearching
	}

	func scopeDidChange() {
		let o = gSearchScopeOption

		searchScopeControl?.setSelected(o.contains(.fPublic),    forSegment: 0)
		searchScopeControl?.setSelected(o.contains(.fMine),      forSegment: 1)
		searchScopeControl?.setSelected(o.contains(.fTrash),     forSegment: 2)
		searchScopeControl?.setSelected(o.contains(.fRecent),    forSegment: 3)
		searchScopeControl?.setSelected(o.contains(.fFavorites), forSegment: 4)
		searchScopeControl?.setSelected(o.contains(.fOrphan),    forSegment: 5)
	}

	func filterDidChange() {
		let o = gFilterOption  // flags for not / highlighting segments

		searchFilterControl?.setSelected(o.contains(.fBookmarks), forSegment: 0)
		searchFilterControl?.setSelected(o.contains(.fNotes),     forSegment: 1)
		searchFilterControl?.setSelected(o.contains(.fIdeas),     forSegment: 2)
	}

	@IBAction func searchScopeAction(sender: ZSegmentedControl) {
		var options = ZSearchScopeOption.fNone

		for index in 0..<sender.segmentCount {
			if  sender.isSelected(forSegment: index) {
				let option = ZSearchScopeOption(rawValue: Int(2.0 ** Double(index)))
				options.insert(option)
			}
		}

		if  options == .fNone {
			options  = .fMine
		}

		gSearchScopeOption = options

		scopeDidChange()
		searchOptionsDidChange()
	}

	@IBAction func searchFilterAction(sender: ZSegmentedControl) {
		var options = ZFilterOption.fNone

		for index in 0..<sender.segmentCount {
			if  sender.isSelected(forSegment: index) {
				let option = ZFilterOption(rawValue: Int(2.0 ** Double(index)))
				options.insert(option)
			}
		}

		if  options == .fNone {
			options  = .fIdeas
		}

		gFilterOption = options

		filterDidChange()
		searchOptionsDidChange()
	}

	func searchOptionsDidChange() {
		gSearchBarController?.updateSearchBox(allowSearchToEnd: false)
		gSearchResultsController?.applyFilter()
		gSearchResultsController?.genericTableUpdate()
	}

	@IBAction func dismissAction(_ sender: ZButton) {
		gSearchBarController?.endSearch()
	}

	func control(_ control: ZControl, textView: ZTextView, doCommandBy commandSelector: Selector) -> Bool { // false means not handled
		let done = commandSelector == Selector(("noop:"))

		if  done {
			gSearchBarController?.endSearch()
		}

		return done
	}

}
