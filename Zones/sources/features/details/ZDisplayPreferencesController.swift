//
//  ZDisplayPreferencesController.swift
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

class ZDisplayPreferencesController: ZGenericController {

	@IBOutlet var     countsModeControl : ZSegmentedControl?
	@IBOutlet var circlesDisplayControl : ZSegmentedControl?
	@IBOutlet var     circlesDisplayBox : NSView?
	@IBOutlet var   colorPreferencesBox : NSView?
    @IBOutlet var    backgroundColorBox : ZColorWell?
    @IBOutlet var    activeMineColorBox : ZColorWell?
	@IBOutlet var          zoneColorBox : ZColorWell?
	@IBOutlet var          baseFontSize : ZSlider?
	@IBOutlet var         lineThickness : ZSlider?
	@IBOutlet var     horizontalSpacing : ZSlider?
	@IBOutlet var    colorfulModeButton : ZButton?
	@IBOutlet var      clearColorButton : ZButton?
	@IBOutlet var          layoutButton : ZHoverableButton?
    override  var          controllerID : ZControllerID { return .idPreferences }

    override func handleSignal(kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vPreferences) {
            let                        grabbed = gSelecting.firstSortedGrab
			countsModeControl?.selectedSegment = gCountsMode.rawValue
            lineThickness?        .doubleValue = Double(gLineThickness)
            baseFontSize?         .doubleValue = Double(gBaseFontSize)
            horizontalSpacing?    .doubleValue = Double(gHorizontalGap)
			circlesDisplayBox?       .isHidden = gMapLayoutMode == .linearMode
			colorPreferencesBox?     .isHidden = !gColorfulMode
            clearColorButton?        .isHidden = !(grabbed?.hasColor ?? true)
			zoneColorBox?               .color =   grabbed?.color ?? kDefaultIdeaColor
			activeMineColorBox?         .color = gActiveColor
			backgroundColorBox?         .color = gAccentColor
			colorfulModeButton?         .title = "Switch to " + (gColorfulMode ? "monochrome" : "colorful")
			layoutButton?               .title = "Switch to " + gMapLayoutMode.next.title

			circlesDisplayControl?.selectSegments(from: gCirclesDisplayMode.indexSet)
            view.setAllSubviewsNeedDisplay()
        }
    }

    // MARK: - actions
    // MARK: -

	@IBAction func sliderAction(_ iSlider: ZSlider) {
		let value = iSlider.doubleValue.float

		if  let     identifier = gConvertFromOptionalUserInterfaceItemIdentifier(iSlider.identifier) {
			switch (identifier) {
			case  "thickness": gLineThickness = value
			case "horizontal": gHorizontalGap = value
			case  "font size":  gBaseFontSize = value
			default:           break
			}

			temporarilyApplyThenDelay(for: 0.2) { flag in
				gPreferencesAreTakingEffect = flag
			}

			gSignal([.spRelayout, .spCrumbs, .spPreferences])
			gExplainPopover?.reexplain()
		}
    }

	@IBAction func layoutButtonAction(_ button: ZHoverableButton) {
		gMapLayoutMode = gMapLayoutMode.next; gRelayoutMaps()

		gSignal([.spPreferences])
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
			gExplainPopover?.reexplain()
        }
	}

	@IBAction func colorfulModeAction(_ button: ZButton) {
		gColorfulMode = !gColorfulMode

		gSignal([.spRelayout, .spPreferences, .spFavoritesMap])
	}

	@IBAction func clearColorAction(_ button: ZButton) {
        if  let     zone  = gSelecting.firstSortedGrab {
            if  let color = zone.colorMaybe {
                UNDO(self) { iUndoSelf in
                    zone.color = color

					gRelayoutMaps()
                }
            }
            
            zone.clearColor()
			gRelayoutMaps()
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
