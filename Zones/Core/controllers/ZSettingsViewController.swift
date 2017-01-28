//
//  ZSettingsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZSliderKind: String {
    case Vertical   = "vertical"
    case Thickness  = "thickness"
    case Horizontal = "horizontal"
}


enum ZColorBoxKind: String {
    case Zones      = "zones"
    case Bookmarks  = "bookmarks"
    case Background = "background"
}


class ZSettingsViewController: ZGenericViewController, ZTableViewDelegate, ZTableViewDataSource {


    @IBOutlet var         fractionInMemory: ZProgressIndicator?
    @IBOutlet var     favoritesTableHeight: NSLayoutConstraint?
    @IBOutlet var graphAlteringModeControl: ZSegmentedControl?
    @IBOutlet var       favoritesTableView: NSTableView?
    @IBOutlet var          totalCountLabel: ZTextField?
    @IBOutlet var           graphNameLabel: ZTextField?
    @IBOutlet var               levelLabel: ZTextField?
    @IBOutlet var             zoneColorBox: ZColorWell?
    @IBOutlet var         bookmarkColorBox: ZColorWell?
    @IBOutlet var       backgroundColorBox: ZColorWell?
    @IBOutlet var        horizontalSpacing: ZSlider?
    @IBOutlet var          verticalSpacing: ZSlider?
    @IBOutlet var                thickness: ZSlider?


    // MARK:- generic methods
    // MARK:-

    
    override func identifier() -> ZControllerID { return .settings }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        let                     count = gCloudManager.zones.count
        let                     total = gTravelManager.manifest.total
        totalCountLabel?        .text = "of \(total), retrieved: \(count)"
        graphNameLabel?         .text = "graph: \(gStorageMode.rawValue)"
        levelLabel?             .text = "level: \((gTravelManager.hereZone?.level)!)"
        view  .zlayer.backgroundColor = gBackgroundColor.cgColor
        fractionInMemory?   .maxValue = Double(total)
        fractionInMemory?.doubleValue = Double(count)

        if let                   here = gTravelManager.hereZone, let tableView = favoritesTableView {
            gFavoritesManager.updateIndexFor(here) { object in
                gFavoritesManager.update()
                tableView.reloadData()

                self.favoritesTableHeight?.constant = CGFloat((gFavoritesManager.count + 1) * 19)
            }
        }
    }


    override func awakeFromNib() {
        fractionInMemory?               .minValue = 0
        graphAlteringModeControl?.selectedSegment = gGraphAlteringMode.rawValue
        thickness?                   .doubleValue = gLineThickness
        verticalSpacing?             .doubleValue = Double(gGenericOffset.height)
        horizontalSpacing?           .doubleValue = Double(gGenericOffset.width)
        backgroundColorBox?                .color = gBackgroundColor
        bookmarkColorBox?                  .color = gBookmarkColor
        zoneColorBox?                      .color = gZoneColor
    }


    func displayViewFor(id: ZSettingsViewID) {
        let type = ZStackableView.self.className()

        gSettingsViewIDs.insert(id)
        view.applyToAllSubviews { (iView: ZView) in
            if type == iView.className {
                let stackView = iView as? ZStackableView

                stackView?.update()
            }
        }
    }


    // MARK:- preference actions
    // MARK:-


    @IBAction func sliderAction(_ iSlider: NSSlider) {
        let value = CGFloat(iSlider.doubleValue)

        if let kind = ZSliderKind(rawValue: iSlider.identifier!) {
            switch (kind) {
            case  .Thickness: gLineThickness = Double(value);                                       break
            case .Horizontal: gGenericOffset = CGSize(width: value, height: gGenericOffset.height); break
            case   .Vertical: gGenericOffset = CGSize(width: gGenericOffset.width, height: value);  break
            }

            signalFor(nil, regarding: .redraw)
        }
    }


    @IBAction func colorBoxAction(_ iColorBox: NSColorWell) {
        let color = iColorBox.color

        if let kind = ZColorBoxKind(rawValue: iColorBox.identifier!) {
            switch (kind) {
            case .Background: gBackgroundColor = color; break
            case  .Bookmarks:   gBookmarkColor = color; break
            case      .Zones:       gZoneColor = color; break
            }

            signalFor(nil, regarding: .redraw)
        }
    }


    @IBAction func graphAlteringModeAction(_ control: ZSegmentedControl) {
        gGraphAlteringMode = ZGraphAlteringMode(rawValue: control.selectedSegment)!
    }


    // MARK:- cloud tool actions
    // MARK:-
    

    @IBAction func emptyTrashButtonAction(_ button: ZButton) {

        // needs elaborate gui, like search results, but with checkboxes and [de]select all checkbox

        //gOperationsManager.emptyTrash {
        //    self.toConsole("eliminated")
        //}
    }


    @IBAction func restoreFromTrashButtonAction(_ button: ZButton) {
        gOperationsManager.undelete {
            self.signalFor(nil, regarding: .redraw)
        }
        
    }


    @IBAction func restoreZoneButtonAction(_ button: ZButton) {
        // similar to gEditingManager.moveInto
        if  let               zone = gSelectionManager.firstGrabbableZone {
            let               root = gTravelManager.rootZone
            gTravelManager.hereZone = root

            root?.needChildren()
            gOperationsManager.children(recursively: true) {
                root?.addAndReorderChild(zone, at: 0)
                gControllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
            }
        }
    }

    
    @IBAction func pushToCloudButtonAction(_ button: ZButton) {
        gCloudManager.royalFlush {}
    }


    // MARK:- favorites table
    // MARK:-


    func numberOfRows(in tableView: NSTableView) -> Int {
        var count = 1

        for zone in gFavoritesManager.favoritesRootZone.children {
            if zone.isBookmark {
                count += 1
            }
        }

        return count
    }

    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        var        value = ""

        if  let     text = row == 0 ? "edit these items" : gFavoritesManager.textAtIndex(row - 1) {
            let needsDot = gFavoritesManager.favoritesIndex == row - 1
            let   prefix = needsDot ? "•" : "  "
            value        = " \(prefix) \(text)"
        }
        
        return value
    }


    func actOnSelection(_ row: Int) {
        gSelectionManager.fullResign()

        if row == 0 {
            gStorageMode = .favorites

            gTravelManager.travel {
                self.signalFor(nil, regarding: .redraw)
            }
        } else if let zone: Zone = gFavoritesManager.zoneAtIndex(row - 1) {
            gFavoritesManager.favoritesIndex = row - 1

            gEditingManager.focusOnZone(zone)
        }
    }


    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let select = gOperationsManager.isReady

        if  select {
            actOnSelection(row)
        }

        return false
    }
}
