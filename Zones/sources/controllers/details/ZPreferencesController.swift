//
//  ZPreferencesController.swift
//  Thoughtful
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
    @IBOutlet var  browsingModeControl: ZSegmentedControl?
    @IBOutlet var insertionModeControl: ZSegmentedControl?
    @IBOutlet var         zoneColorBox: ZColorWell?
    @IBOutlet var   backgroundColorBox: ZColorWell?
    @IBOutlet var  dragTargetsColorBox: ZColorWell?
    @IBOutlet var     clearColorButton: ZButton?
    @IBOutlet var      verticalSpacing: ZSlider?
    @IBOutlet var            thickness: ZSlider?
    @IBOutlet var              stretch: ZSlider?
    @IBOutlet var           ideasLabel: ZTextField?
    override  var         controllerID: ZControllerID { return .idPreferences }


    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		if ![.eLaunchDone, .eStartup, .eSearch, .eFound, .eCrumbs, .eSwap, .eRing].contains(iKind) {
            let                           grabbed = gSelecting.firstSortedGrab
            insertionModeControl?.selectedSegment = gListGrowthMode.rawValue
            browsingModeControl? .selectedSegment = gBrowsingMode.rawValue
            countsModeControl?   .selectedSegment = gCountsMode.rawValue
            thickness?               .doubleValue = gLineThickness
            verticalSpacing?         .doubleValue = Double(gGenericOffset.height)
            stretch?                 .doubleValue = Double(gGenericOffset.width)
            dragTargetsColorBox?           .color = gRubberbandColor
            backgroundColorBox?            .color = gBackgroundColor
            zoneColorBox?                  .color =   grabbed?.color ?? kDefaultZoneColor
            clearColorButton?           .isHidden = !(grabbed?.hasColor ?? true)

            view.setAllSubviewsNeedDisplay()
        }
    }


    // MARK:- actions
    // MARK:-


    @IBAction func sliderAction(_ iSlider: ZSlider) {
        let value = CGFloat(iSlider.doubleValue)

        if  let     identifier = convertFromOptionalUserInterfaceItemIdentifier(iSlider.identifier) {
			switch (identifier) {
				case "thickness": gLineThickness = Double(value)
				case   "stretch": gGenericOffset = CGSize(width: value, height: gGenericOffset.height)
				case      "size": gGenericOffset = CGSize(width: gGenericOffset.width, height: value)
				default:           break
			}

            redrawGraph()
        }
    }


    @IBAction func colorBoxAction(_ iColorBox: ZColorWell) {
        let color = iColorBox.color

        if  let     identifier = convertFromOptionalUserInterfaceItemIdentifier(iColorBox.identifier) {
			switch (identifier) {
				case "drag targets":        gRubberbandColor = color
				case   "background":        gBackgroundColor = color
				case        "zones": gSelecting.grabbedColor = color
				default:             break
			}

            gControllers.signalAndSync(nil, regarding: .eRelayout) {}
        }
    }


    @IBAction func clearColorAction(_ button: ZButton) {
        if  let     grab = gSelecting.firstSortedGrab {
            if let color = grab.colorMaybe {
                UNDO(self) { iUndoSelf in
                    grab.color = color
                    
                    gControllers.signalAndSync(grab, regarding: .eRelayout) {}
                }
            }
            
            grab.clearColor()
            gControllers.signalAndSync(grab, regarding: .eRelayout) {}
        }
    }


    @IBAction func segmentedControlAction(_ iControl: ZSegmentedControl) {
        let          selection = iControl.selectedSegment
        if  let     identifier = convertFromOptionalUserInterfaceItemIdentifier(iControl.identifier) {
			switch (identifier) {
				case "counts":    gCountsMode    = ZCountsMode   (rawValue: selection)!; redrawGraph()
				case "browsing":  gBrowsingMode  = ZBrowsingMode (rawValue: selection)!; signalMultiple([.eMain, .eGraph])
				case "direction": gListGrowthMode = ZListGrowthMode(rawValue: selection)!; signalMultiple([.eMain, .eGraph])
				default: break
			}
        }
    }

}
