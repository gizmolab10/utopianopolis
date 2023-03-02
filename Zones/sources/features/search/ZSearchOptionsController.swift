//
//  ZSearchOptionsController.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/1/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

var gSearchOptionsController: ZSearchOptionsController? { return gControllers.controllerForID(.idSearchOptions) as? ZSearchOptionsController }

class ZSearchOptionsController: ZGenericController {

	override  var controllerID        : ZControllerID { return .idSearchOptions }
	@IBOutlet var searchScopeControl  : ZSegmentedControl?
	@IBOutlet var searchTypeControl   : ZSegmentedControl?
	@IBOutlet var searchOptionsView   : ZView?

	func updateOptionView() { searchStateDidChange() }

	override func controllerSetup(with mapView: ZMapView?) {
		searchOptionsView?.zlayer.backgroundColor = kClearColor.cgColor

		searchStateDidChange()
	}

	override func handleSignal(_ iSignalObject: Any?, kind: ZSignalKind) {
		filterDidChange()
		scopeDidChange()
		searchStateDidChange()
	}

	func searchStateDidChange() {
		searchOptionsView?.isHidden = gIsNotSearching

		gMainController?.searchStateDidChange() // moved dismiss button to main controller
	}

	func scopeDidChange() {
		let o = gSearchScope

		searchScopeControl?.setSelected(o.contains(.fPublic),    forSegment: 0)
		searchScopeControl?.setSelected(o.contains(.fMine),      forSegment: 1)
		searchScopeControl?.setSelected(o.contains(.fTrash),     forSegment: 2)
		searchScopeControl?.setSelected(o.contains(.fFavorites), forSegment: 3)
		searchScopeControl?.setSelected(o.contains(.fOrphan),    forSegment: 4)
	}

	func filterDidChange() {
		let o = gFilterOption  // flags for not / highlighting segments

		searchTypeControl?.setSelected(o.contains(.fBookmarks), forSegment: 0)
		searchTypeControl?.setSelected(o.contains(.fNotes),     forSegment: 1)
		searchTypeControl?.setSelected(o.contains(.fIdeas),     forSegment: 2)
	}

	@IBAction func searchScopeAction(sender: ZSegmentedControl) {
		var options = ZSearchScope.fNone

		for index in 0..<sender.segmentCount {
			if  sender.isSelected(forSegment: index) {
				let option = ZSearchScope(rawValue: Int(1 << index))
				options.insert(option)
			}
		}

		if  options == .fNone {
			options  = .fMine
		}

		gSearchScope = options

		scopeDidChange()
		searchOptionsDidChange()
	}

	@IBAction func searchTypeAction(sender: ZSegmentedControl) {
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
		gSearchBarController?.updateSearchBar(allowSearchToEnd: false)
		gSearchResultsController?.applyFilter()
		gSearchResultsController?.genericTableUpdate()
	}

	func control(_ control: ZControl, textView: ZTextView, doCommandBy commandSelector: Selector) -> Bool { // false means not handled
		let done = commandSelector == Selector(("noop:"))

		if  done {
			gSearchBarController?.endSearch()
		}

		return done
	}

}
