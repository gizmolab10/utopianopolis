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


    @IBOutlet var        countsModeControl: ZSegmentedControl?
    @IBOutlet var graphAlteringModeControl: ZSegmentedControl?
    @IBOutlet var             zoneColorBox: ZColorWell?
    @IBOutlet var         bookmarkColorBox: ZColorWell?
    @IBOutlet var       backgroundColorBox: ZColorWell?
    @IBOutlet var      dragTargetsColorBox: ZColorWell?
    @IBOutlet var        horizontalSpacing: ZSlider?
    @IBOutlet var          verticalSpacing: ZSlider?
    @IBOutlet var                thickness: ZSlider?
    @IBOutlet var         clearColorButton: NSButton?


    override func identifier() -> ZControllerID { return .preferences }


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        let                               grabbed = gSelectionManager.firstGrab
        view              .zlayer.backgroundColor = CGColor.clear
        graphAlteringModeControl?.selectedSegment = gGraphAlteringMode.rawValue
        countsModeControl?       .selectedSegment = gCountsMode.rawValue
        thickness?                   .doubleValue = gLineThickness
        verticalSpacing?             .doubleValue = Double(gGenericOffset.height)
        horizontalSpacing?           .doubleValue = Double(gGenericOffset.width)
        dragTargetsColorBox?               .color = gDragTargetsColor
        backgroundColorBox?                .color = gBackgroundColor
        bookmarkColorBox?                  .color = gBookmarkColor
        zoneColorBox?                      .color =  grabbed.color
        clearColorButton?               .isHidden = !grabbed.hasColor
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
            case "drag targets":                 gDragTargetsColor = color
            case   "background":                  gBackgroundColor = color
            case    "bookmarks":                    gBookmarkColor = color
            case        "zones": gSelectionManager.firstGrab.color = color
            default:             break
            }

            signalFor(nil, regarding: .redraw)
        }
    }


    @IBAction func clearColorAction(_ button: NSButton) {
        let           grab = gSelectionManager.firstGrab
        if  let      color = grab._color {
            UNDO(self) { iUndoSelf in
                grab.color = color

                iUndoSelf.syncToCloudAndSignalFor(grab, regarding: .redraw) {}
            }
        }

        grab.clearColor()
        syncToCloudAndSignalFor(grab, regarding: .redraw) {}
    }


    @IBAction func segmentedControlAction(_ iControl: ZSegmentedControl) {
        let          selection = iControl.selectedSegment
        if  let     identifier = iControl.identifier {
            switch (identifier) {
            case "counts":    gCountsMode        = ZCountsMode       (rawValue: selection)!
            case "direction": gGraphAlteringMode = ZGraphAlteringMode(rawValue: selection)!
            default: break
            }
        }

        signalFor(nil, regarding: .data)
    }

}
