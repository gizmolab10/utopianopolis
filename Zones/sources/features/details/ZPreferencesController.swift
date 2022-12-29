//
//  ZPreferencesController.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/13/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

enum ZCountsMode: Int { // do not change the order, they are persisted
	case none
	case dots
	case fetchable
	case progeny
}

class ZPreferencesController: ZGenericController {

	@IBOutlet var     countsModeControl : ZSegmentedControl?
	@IBOutlet var circlesDisplayControl : ZSegmentedControl?
	@IBOutlet var     circlesDisplayBox : NSView?
	@IBOutlet var   colorPreferencesBox : NSView?
    @IBOutlet var    backgroundColorBox : ZColorWell?
    @IBOutlet var    activeMineColorBox : ZColorWell?
	@IBOutlet var          zoneColorBox : ZColorWell?
	@IBOutlet var              fontSize : ZSlider?
	@IBOutlet var         lineThickness : ZSlider?
	@IBOutlet var     horizontalSpacing : ZSlider?
	@IBOutlet var    colorfulModeButton : ZButton?
	@IBOutlet var      clearColorButton : ZButton?
    override  var          controllerID : ZControllerID { return .idPreferences }

    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vPreferences) {
            let                            grabbed = gSelecting.firstSortedGrab
            countsModeControl?    .selectedSegment = gCountsMode   .rawValue
            lineThickness?            .doubleValue = Double(gLineThickness)
            fontSize?                 .doubleValue = Double(gBaseFontSize)
            horizontalSpacing?        .doubleValue = Double(gHorizontalGap)
			circlesDisplayBox?           .isHidden = gMapLayoutMode == .linearMode
			colorPreferencesBox?         .isHidden = !gColorfulMode
            clearColorButton?            .isHidden = !(grabbed?.hasColor ?? true)
			zoneColorBox?                   .color =   grabbed?.color ?? kDefaultIdeaColor
			activeMineColorBox?             .color = gActiveColor
			backgroundColorBox?             .color = gAccentColor
			colorfulModeButton?             .title = gColorfulMode ? "colorful" : "monochrome"

			circlesDisplayControl?.selectSegments(from: gCirclesDisplayMode.indexSet)
            view.setAllSubviewsNeedDisplay()
        }
    }

    // MARK: - actions
    // MARK: -

	@IBAction func sliderAction(_ iSlider: ZSlider) {
        let value = CGFloat(iSlider.doubleValue)

		if  let     identifier = gConvertFromOptionalUserInterfaceItemIdentifier(iSlider.identifier) {
			switch (identifier) {
			case  "thickness": gLineThickness = value
			case "horizontal": gHorizontalGap = value
			case  "font size":  gBaseFontSize = value
			default:           break
			}

			temporarilyApplyThenDelay(for: 0.2) { flag in
				gIgnoreEvents = flag
			}

			gSignal([.spRelayout, .spCrumbs, .spPreferences])
		}
    }

    @IBAction func colorBoxAction(_ iColorBox: ZColorWell) {
        let color = iColorBox.color

        if  let     identifier = gConvertFromOptionalUserInterfaceItemIdentifier(iColorBox.identifier) {
			switch (identifier) {
				case "drag targets":            gActiveColor = color
				case       "accent":            gAccentColor = color
				case        "zones": gSelecting.grabbedColor = color
				default:             break
			}

			gSignal([.sDatum])
        }
	}

	@IBAction func colorfulModeAction(_ button: ZButton) {
		gColorfulMode = !gColorfulMode

		gSignal([.spRelayout, .spPreferences, .spSmallMap])
	}

	@IBAction func clearColorAction(_ button: ZButton) {
        if  let     zone  = gSelecting.firstSortedGrab {
            if  let color = zone.colorMaybe {
                UNDO(self) { iUndoSelf in
                    zone.color = color

					gRelayoutMaps(for: zone)
                }
            }
            
            zone.clearColor()
			gRelayoutMaps(for: zone)
        }
    }

    @IBAction func segmentedControlAction(_ iControl: ZSegmentedControl) {
        if  let     identifier = gConvertFromOptionalUserInterfaceItemIdentifier(iControl.identifier) {
			switch (identifier) {
			case "counts":         gCountsMode = ZCountsMode(rawValue: iControl.selectedSegment)!
			case "layout": gCirclesDisplayMode = ZCirclesDisplayMode.createFrom(iControl.seletedSegments)
			default:       return
			}

			gRelayoutMaps()
        }
    }

}
