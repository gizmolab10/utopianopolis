//
//  ZEnableSubscriptions.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/2/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import AppKit
#elseif os(iOS)
import UIKit
#endif

var gHasEnabledSubscription: Bool { return gProducts.hasEnabledSubscription || true }

extension ZoneWidget {

	func printWidget() {
		if  gHasEnabledSubscription,
			let   mapView = controller?.mapView {
			let   current = frame.expandedEquallyBy(40.0).offsetBy(dx: 15.0, dy: 22.0)
			let     prior = mapView.frame
			let    offset = gMapOffset
			mapView.frame = current
			gMapOffset    = .zero

			gDetailsController?.temporarilyHideView(for: .vFavorites) {
				gRelayoutMaps()
				mapView.printView()
			}

			mapView.frame = prior
			gMapOffset    = offset

			gRelayoutMaps()
		}
	}

}

extension ZSearching {

	func showSearch(_ OPTION: Bool = false) {
		if  gHasEnabledSubscription {
			searchState = .sEntry // don't call setSearchStateTo, it has unwanted side-effects

			gDispatchSignals([OPTION ? .sFound : .sSearch])
		}
	}

}

extension ZEssayView {

	@objc override func printView() { // ZTextView
		if  gHasEnabledSubscription {
			gIsPrinting      = true
			var view: NSView = self
			let    printInfo = NSPrintInfo.shared
			let pmPageFormat = PMPageFormat(printInfo.pmPageFormat())
			if  let    tView = view as? NSTextView {
				let    frame = CGRect(origin: .zero, size: CGSize(width: 6.5 * 72.0, height: 9.5 * 72.0))
				let    nView = NSTextView(frame: frame)
				view         = nView

				nView.insertText(tView.textStorage as Any, replacementRange: NSRange())
			}

			PMSetScale(pmPageFormat, 100.0)
			PMSetOrientation(pmPageFormat, PMOrientation(kPMPortrait), false)
			printInfo.updateFromPMPrintSettings()
			printInfo.updateFromPMPageFormat()
			NSPrintOperation(view: view, printInfo: printInfo).run()
			gIsPrinting      = false
		}
	}

}

#if os(OSX)
extension ZView {

	@objc func printView() { // ZView
		if  gHasEnabledSubscription {
			gIsPrinting         = true
			let       printInfo = NSPrintInfo.shared
			printInfo.topMargin = 72.0
			let         isWider = bounds.width > bounds.height
			let     orientation = PMOrientation(isWider ? kPMLandscape : kPMPortrait)
			let    pmPageFormat = PMPageFormat(printInfo.pmPageFormat())
			var            size = printInfo.paperSize.multiplyBy(0.8)

			if  isWider {
				size            = size.swapped
			}

			let           scale = 100.0 * Double(bounds.size.scaleToFit(size))

			PMSetScale(pmPageFormat, scale)
			PMSetOrientation(pmPageFormat, orientation, false)
			printInfo.updateFromPMPrintSettings()
			printInfo.updateFromPMPageFormat()
			NSPrintOperation(view: self, printInfo: printInfo).run()
			gIsPrinting         = false
		}
	}

}
#endif
