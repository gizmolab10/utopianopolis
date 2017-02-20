//
//  ZoneDot.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneDot: ZView, ZGestureRecognizerDelegate {


    var      innerDot: ZoneDot?
    var    isInnerDot: Bool = false
    var      isToggle: Bool = true
    var        widget: ZoneWidget?
    var    widgetZone: Zone?
    var   dragGesture: ZGestureRecognizer?
    var doubleGesture: ZGestureRecognizer?
    var singleGesture: ZGestureRecognizer?


    var width: CGFloat {
        get {
            return innerDot!.bounds.width
        }
    }


    var isToggleTarget: Bool {
        return isToggle && widgetZone == gSelectionManager.targetDropZone
    }


    var isDropTarget: Bool {
        if  let   index = widgetZone?.siblingIndex, !isToggle {
            let isIndex = gSelectionManager.targetLineIndices?.contains(index)
            let  isDrop = widgetZone?.parentZone == gSelectionManager.targetDropZone

            if isDrop && isIndex! {
                return true
            }
        }

        return false
    }


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        if isInnerDot, let zone = widgetZone {
            let      isBookmark = zone.isBookmark || zone.isRootOfFavorites
            let        isTarget = isToggleTarget || isDropTarget
            isHidden            = !zone.hasChildren && !zone.isBookmark && isToggle && !isToggleTarget
            let     strokeColor = isBookmark ? gBookmarkColor : gZoneColor
            let shouldHighlight = isToggle ? (!(zone.showChildren) || isBookmark || isToggleTarget) : (zone.isSelected || isDropTarget)
            let       fillColor = shouldHighlight ? isTarget ? gDragTargetsColor : strokeColor : ZColor.clear
            let       thickness = CGFloat(gLineThickness)
            let            path = ZBezierPath(ovalIn: dirtyRect.insetBy(dx: thickness, dy: thickness))

            fillColor.setFill()
            strokeColor.setStroke()
            path.lineWidth = thickness
            path.flatness = 0.0001
            path.stroke()
            path.fill()
        }
    }


    func setupForWidget(_ iWidget: ZoneWidget, asToggle: Bool) {
        widgetZone = iWidget.widgetZone
        isToggle   = asToggle
        widget     = iWidget

        if isInnerDot {
            snp.makeConstraints { (make: ConstraintMaker) in
                let width = CGFloat(asToggle ? gDotHeight : gDotHeight * 0.75)
                let  size = CGSize(width: width, height: CGFloat(gDotHeight))

                make.size.equalTo(size)
            }

            setNeedsDisplay(frame)
        } else {
            if  innerDot            == nil {
                innerDot             = ZoneDot()
                innerDot?.isInnerDot = true

                addSubview(innerDot!)
            }

            clearGestures()

            singleGesture = createPointGestureRecognizer(self, action: #selector(ZoneDot.singleEvent), clicksRequired: 1)

            if !isToggle {
                dragGesture = createDragGestureRecognizer(self, action: #selector(ZoneDot.dragEvent))
                gSelectionManager.zoneBeingDragged = nil
            }

            innerDot?.setupForWidget(iWidget, asToggle: isToggle)
            snp.makeConstraints { (make: ConstraintMaker) in
                make.size.equalTo(CGSize(width: gFingerBreadth, height: gFingerBreadth))
                make.center.equalTo(innerDot!)
            }
        }

        #if os(iOS)
        backgroundColor = ZColor.clear
        #endif

        updateConstraints()
    }


    func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: ZGestureRecognizer) -> Bool {
        return isToggle ? false : gestureRecognizer == singleGesture && otherGestureRecognizer == doubleGesture
    }
    

    func singleEvent(_ iGesture: ZGestureRecognizer?) {
        if isToggle {
            gEditingManager.toggleDotActionOnZone(widgetZone, recursively: false)
        } else {
            gSelectionManager.deselect()
            widgetZone?.grab()
        }
    }


    func dragEvent(_ iGesture: ZGestureRecognizer?) {
        let isHere = widgetZone == gHere

        if iGesture?.state == .began {
            gSelectionManager.deselect()
            widgetZone?.grab()

            if !isHere {
                gSelectionManager.zoneBeingDragged = widgetZone
            }

            widget?.setNeedsDisplay()
        }

        if !isHere {
            editorController?.handleDragEvent(iGesture)
        }
    }
}
