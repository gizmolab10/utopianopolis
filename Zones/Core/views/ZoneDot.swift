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

        if  let            zone = widgetZone, isInnerDot {
            let      isBookmark = zone.isBookmark || zone.isRootOfFavorites
            isHidden            = isToggle && !(zone.hasChildren     || isBookmark || isToggleTarget)
            let shouldHighlight = isToggle ?  (!zone.showChildren    || isBookmark || isToggleTarget) : zone.isSelected
            let     strokeColor = isToggleTarget ? gDragTargetsColor :  isBookmark  ? gBookmarkColor : gZoneColor
            let       fillColor = shouldHighlight ? strokeColor : gBackgroundColor
            let       thickness = CGFloat(gLineThickness)
            let           inset = thickness / lineThicknessDivisor
            let            path = ZBezierPath(ovalIn: dirtyRect.insetBy(dx: inset, dy: inset))

            fillColor.setFill()
            strokeColor.setStroke()
            path.lineWidth = thickness * 2.0
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
                let width = CGFloat(asToggle ? gDotHeight : gDotWidth)
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
        setNeedsDisplay()
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
        }

        if !isHere {
            editorController?.handleDragEvent(iGesture)
        }
    }
}
