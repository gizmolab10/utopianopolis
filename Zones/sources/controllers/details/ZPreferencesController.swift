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
    @IBOutlet var    horizontalSpacing: ZSlider?
    @IBOutlet var      verticalSpacing: ZSlider?
    @IBOutlet var            thickness: ZSlider?
    @IBOutlet var     clearColorButton: ZButton?
    @IBOutlet var           ideasLabel: ZTextField?
    override var backgroundColor: CGColor { return gDarkishBackgroundColor }


    override func setup() {
        controllerID = .preferences
    }


    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        if  iKind != .eStartup {
            let                           grabbed = gSelecting.firstGrab
            insertionModeControl?.selectedSegment = gInsertionMode.rawValue
            browsingModeControl? .selectedSegment = gBrowsingMode.rawValue
            countsModeControl?   .selectedSegment = gCountsMode.rawValue
            thickness?               .doubleValue = gLineThickness
            verticalSpacing?         .doubleValue = Double(gGenericOffset.height)
            horizontalSpacing?       .doubleValue = Double(gGenericOffset.width)
            dragTargetsColorBox?           .color = gRubberbandColor
            backgroundColorBox?            .color = gBackgroundColor
            zoneColorBox?                  .color =  grabbed.color
            clearColorButton?           .isHidden = !grabbed.hasColor

            view.setAllSubviewsNeedDisplay()
        }
    }


    // MARK:- actions
    // MARK:-


    @IBAction func sliderAction(_ iSlider: ZSlider) {
        let value = CGFloat(iSlider.doubleValue)

        if  let     identifier = convertFromOptionalNSUserInterfaceItemIdentifier(iSlider.identifier) {
            switch (identifier) {
            case  "thickness": gLineThickness = Double(value)
            case "horizontal": gGenericOffset = CGSize(width: value, height: gGenericOffset.height)
            case   "vertical": gGenericOffset = CGSize(width: gGenericOffset.width, height: value)
            default:           break
            }

            gControllers.signalFor(nil, regarding: .eRelayout)
        }
    }


    @IBAction func colorBoxAction(_ iColorBox: ZColorWell) {
        let color = iColorBox.color

        if  let     identifier = convertFromOptionalNSUserInterfaceItemIdentifier(iColorBox.identifier) {
            switch (identifier) {
            case "drag targets":               gRubberbandColor = color
            case   "background":               gBackgroundColor = color
            case        "zones": gSelecting.grabbedColor = color
            default:             break
            }

            gControllers.syncToCloudAfterSignalFor(nil, regarding: .eRelayout) {}
        }
    }


    @IBAction func clearColorAction(_ button: ZButton) {
        let           grab = gSelecting.firstGrab
        if  let      color = grab._color {
            UNDO(self) { iUndoSelf in
                grab.color = color

                gControllers.syncToCloudAfterSignalFor(grab, regarding: .eRelayout) {}
            }
        }

        grab.clearColor()
        gControllers.syncToCloudAfterSignalFor(grab, regarding: .eRelayout) {}
    }


    @IBAction func segmentedControlAction(_ iControl: ZSegmentedControl) {
        let          selection = iControl.selectedSegment
        if  let     identifier = convertFromOptionalNSUserInterfaceItemIdentifier(iControl.identifier) {
            switch (identifier) {
            case "counts":    gCountsMode    = ZCountsMode   (rawValue: selection)!; gControllers.signalFor(nil, regarding: .eRelayout)
            case "browsing":  gBrowsingMode  = ZBrowsingMode (rawValue: selection)!
            case "direction": gInsertionMode = ZInsertionMode(rawValue: selection)!
            default: break
            }
        }
    }

}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromOptionalNSUserInterfaceItemIdentifier(_ input: NSUserInterfaceItemIdentifier?) -> String? {
	guard let input = input else { return nil }
	return input.rawValue
}
