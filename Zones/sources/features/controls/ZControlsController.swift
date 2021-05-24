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

	override  var controllerID         : ZControllerID { return .idControls }
	@IBOutlet var mapControls          : ZMapControlsView?
	@IBOutlet var searchOptionsControl : ZSegmentedControl?
	@IBOutlet var searchOptionsView    : ZView?
	@IBOutlet var dismissButton        : ZButton?

	@IBAction func search(_ sender: ZButton) { gSearching.showSearch() }
	func updateForState() { searchOptionsView?.isHidden = gSearching.state == .sNot }
	func updateOptionView() { updateForState() }
	func update() { searchOptionsView?.isHidden = gSearching.state == .sNot }

	override func setup() {
		searchOptionsView?.zlayer.backgroundColor = kWhiteColor.cgColor

		update()
	}

	override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
		mapControls?.setupAndRedraw()
		updateSearchOptions()
		update()
		let hideSearch = !gIsSearchMode

		switch iKind {
			case .sSearch: searchOptionsView?.isHidden = hideSearch
			case .sFound:  searchOptionsView?.isHidden = hideSearch
			default: break
		}
	}

	func updateSearchOptions() {
		let o = gFilterOption  // flags for not / highlighting segments

		searchOptionsControl?.setSelected(o.contains(.fBookmarks), forSegment: 0)
		searchOptionsControl?.setSelected(o.contains(.fNotes),     forSegment: 1)
		searchOptionsControl?.setSelected(o.contains(.fIdeas),     forSegment: 2)
		searchOptionsControl?.action = #selector(searchOptionAction)
		searchOptionsControl?.target = self
	}

	@IBAction func searchOptionAction(sender: ZSegmentedControl) {
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

		gSearchBarController?.updateSearchBox()
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