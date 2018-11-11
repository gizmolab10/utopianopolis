//
//  ZPreferencesController.swift
//  Zones
//
//  Created by Jonathan Sand on 4/13/17.
//  Copyright © 2017 Zones. All rights reserved.
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
        if  iKind != .startup {
            let                           grabbed = gSelectionManager.firstGrab
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

        if  let     identifier = iSlider.identifier {
            switch (identifier) {
            case  "thickness": gLineThickness = Double(value)
            case "horizontal": gGenericOffset = CGSize(width: value, height: gGenericOffset.height)
            case   "vertical": gGenericOffset = CGSize(width: gGenericOffset.width, height: value)
            default:           break
            }

            signalFor(nil, regarding: .redraw)
        }
    }


    @IBAction func colorBoxAction(_ iColorBox: ZColorWell) {
        let color = iColorBox.color

        if  let     identifier = iColorBox.identifier {
            switch (identifier) {
            case "drag targets":               gRubberbandColor = color
            case   "background":               gBackgroundColor = color
            case        "zones": gSelectionManager.grabbedColor = color
            default:             break
            }

            gControllersManager.syncToCloudAfterSignalFor(nil, regarding: .redraw) {}
        }
    }


    @IBAction func clearColorAction(_ button: ZButton) {
        let           grab = gSelectionManager.firstGrab
        if  let      color = grab._color {
            UNDO(self) { iUndoSelf in
                grab.color = color

                gControllersManager.syncToCloudAfterSignalFor(grab, regarding: .redraw) {}
            }
        }

        grab.clearColor()
        gControllersManager.syncToCloudAfterSignalFor(grab, regarding: .redraw) {}
    }


    @IBAction func segmentedControlAction(_ iControl: ZSegmentedControl) {
        let          selection = iControl.selectedSegment
        if  let     identifier = iControl.identifier {
            switch (identifier) {
            case "counts":    gCountsMode    = ZCountsMode   (rawValue: selection)!; signalFor(nil, regarding: .redraw)
            case "browsing":  gBrowsingMode  = ZBrowsingMode (rawValue: selection)!
            case "direction": gInsertionMode = ZInsertionMode(rawValue: selection)!
            default: break
            }
        }
    }

}
