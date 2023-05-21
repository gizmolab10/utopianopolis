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

	override  var controllerID  : ZControllerID { return .idSearchOptions }
	@IBOutlet var filterControl : ZSegmentedControl?
	@IBOutlet var scopeControl  : ZSegmentedControl?
	@IBOutlet var status        : ZTextField?

	override func controllerSetup(with mapView: ZMapView?) {
		view.zlayer.backgroundColor = kClearColor.cgColor

		searchStateDidChange()
	}

	override func handleSignal(kind: ZSignalKind) {
		filterDidChange()
		scopeDidChange()
		searchStateDidChange()
		updateStatus()
	}

	func updateStatus() {
		let         show = gSearchStateIsList
		status?.isHidden = !show

		if  show,
			let    count = gSearchResultsController?.filteredResultsCount {
			status?.text = "found \(count)"
		}
	}

	func searchStateDidChange() {
		gMainController?     .searchStateDidChange()
		gSearchBarController?.searchStateDidChange()
	}

	func scopeDidChange() {
		let o = gSearchScope

		scopeControl? .setSelected(o.contains(.sMine),      forSegment: 0)
		scopeControl? .setSelected(o.contains(.sPublic),    forSegment: 1)
		scopeControl? .setSelected(o.contains(.sFavorites), forSegment: 2)
		scopeControl? .setSelected(o.contains(.sOrphan),    forSegment: 3)
		scopeControl? .setSelected(o.contains(.sTrash),     forSegment: 4)
	}

	func filterDidChange() {
		let o = gSearchFilter    // flags for not / highlighting segments

		filterControl?.setSelected(o.contains(.fBookmarks), forSegment: 0)
		filterControl?.setSelected(o.contains(.fNotes),     forSegment: 1)
		filterControl?.setSelected(o.contains(.fIdeas),     forSegment: 2)
	}

	@IBAction func searchScopeAction(sender: ZSegmentedControl) {
		var options = ZSearchScope.sNone

		for index in 0..<sender.segmentCount {
			if  sender.isSelected(forSegment: index) {
				let option = ZSearchScope(rawValue: 1 << index)

				options.insert(option)
			}
		}

		if  options == .sNone {
			options  = .sMine
		}

		gSearchScope = options

		scopeDidChange()
		searchOptionsDidChange()
	}

	@IBAction func searchFilterAction(sender: ZSegmentedControl) {
		var options = ZSearchFilter.fNone

		for index in 0..<sender.segmentCount {
			if  sender.isSelected(forSegment: index) {
				let option = ZSearchFilter(rawValue: 1 << index)

				options.insert(option)
			}
		}

		if  options == .fNone {
			options  = .fIdeas
		}

		gSearchFilter = options

		filterDidChange()
		searchOptionsDidChange()
	}

	func searchOptionsDidChange() {
		if  gSearching.searchState == .sList {
			gSearchBarController?.updateSearchBar(allowSearchToEnd: false)
			gSearchResultsController?.applySearchOptions()
			gSearchResultsController?.genericTableUpdate()
		}
	}

	func control(_ control: ZControl, textView: ZTextView, doCommandBy commandSelector: Selector) -> Bool { // false means not handled
		let done = commandSelector == Selector(("noop:"))

		if  done {
			gSearchBarController?.endSearch()
		}

		return done
	}

}
