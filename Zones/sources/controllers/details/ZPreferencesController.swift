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

class ZPreferencesController: ZGenericController {

    @IBOutlet var    countsModeControl: ZSegmentedControl?
	@IBOutlet var  colorPreferencesBox: NSView?
    @IBOutlet var   backgroundColorBox: ZColorWell?
    @IBOutlet var   activeMineColorBox: ZColorWell?
	@IBOutlet var         zoneColorBox: ZColorWell?
	@IBOutlet var   showTooltipsButton: ZButton?
    @IBOutlet var     clearColorButton: ZButton?
    @IBOutlet var      verticalSpacing: ZSlider?
    @IBOutlet var            thickness: ZSlider?
    @IBOutlet var              stretch: ZSlider?
    override  var         controllerID: ZControllerID { return .idPreferences }

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		if ![.sLaunchDone, .sStartup, .sSearch, .sFound, .sCrumbs, .sSwap, .sFavorites].contains(iKind) {
            let                           grabbed = gSelecting.firstSortedGrab
            countsModeControl?   .selectedSegment = gCountsMode.rawValue
            thickness?               .doubleValue = gLineThickness
            verticalSpacing?         .doubleValue = Double(gGenericOffset.height)
            stretch?                 .doubleValue = Double(gGenericOffset.width)
            activeMineColorBox?            .color = gActiveColor
            backgroundColorBox?            .color = gAccentColor
            zoneColorBox?                  .color =   grabbed?.color ?? kBlueColor
            clearColorButton?           .isHidden = !(grabbed?.hasColor ?? true)
			colorPreferencesBox?        .isHidden = !gColorfulMode
			showTooltipsButton?            .state = gShowToolTips ? .on : .off

            view.setAllSubviewsNeedDisplay()
        }
    }

    // MARK:- actions
    // MARK:-

	@IBAction func toggleTooltipsAction(_ button: ZButton) {
		gShowToolTips = (button.state == .on)

		FOREGROUND {
			gSignal([.sRelayout])
		}
	}

    @IBAction func sliderAction(_ iSlider: ZSlider) {
        let value = CGFloat(iSlider.doubleValue)

        if  let     identifier = convertFromOptionalUserInterfaceItemIdentifier(iSlider.identifier) {
			switch (identifier) {
				case "thickness": gLineThickness = Double(value)
				case   "stretch": gGenericOffset = CGSize(width: value, height: gGenericOffset.height)
				case      "size": gGenericOffset = CGSize(width: gGenericOffset.width, height: value)
				default:           break
			}

            gRedrawGraph()
        }
    }


    @IBAction func colorBoxAction(_ iColorBox: ZColorWell) {
        let color = iColorBox.color

        if  let     identifier = convertFromOptionalUserInterfaceItemIdentifier(iColorBox.identifier) {
			switch (identifier) {
				case "drag targets":        gActiveColor = color
				case       "accent":            gAccentColor = color
				case        "zones": gSelecting.grabbedColor = color
				default:             break
			}

            gRedrawGraph()
        }
    }


    @IBAction func clearColorAction(_ button: ZButton) {
        if  let     grab = gSelecting.firstSortedGrab {
            if let color = grab.colorMaybe {
                UNDO(self) { iUndoSelf in
                    grab.color = color

					gRedrawGraph(for: grab)
                }
            }
            
            grab.clearColor()
			gRedrawGraph(for: grab)
        }
    }


    @IBAction func segmentedControlAction(_ iControl: ZSegmentedControl) {
        let          selection = iControl.selectedSegment
        if  let     identifier = convertFromOptionalUserInterfaceItemIdentifier(iControl.identifier) {
			switch (identifier) {
				case "counts": gCountsMode = ZCountsMode    (rawValue: selection)!; gRedrawGraph()
				default: break
			}
        }
    }

}
