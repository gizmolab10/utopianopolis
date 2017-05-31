//
//  ZoneDot.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneDot: ZView, ZGestureRecognizerDelegate {


    var         widget: ZoneWidget?
    var       innerDot: ZoneDot?
    var       isToggle: Bool = true
    var     isInnerDot: Bool = false
    var     widgetZone: Zone?
    var    dragGesture: ZGestureRecognizer?
    var  singleGesture: ZGestureRecognizer?
    var   isDragTarget: Bool { return widgetZone == gSelectionManager.dragDropZone }


    var innerOrigin: CGPoint? {
        if  let inner = innerDot {
            let  rect = inner.convert(inner.bounds, to: self)

            return rect.origin
        }

        return nil
    }


    var innerExtent: CGPoint? {
        if  let inner = innerDot {
            let  rect = inner.convert(inner.bounds, to: self)

            return rect.extent
        }

        return nil
    }


    var isDropTarget: Bool {
        if  let   index = widgetZone?.siblingIndex, !isToggle {
            let isIndex = gSelectionManager.dragDropIndices?.contains(index)
            let  isDrop = widgetZone?.parentZone == gSelectionManager.dragDropZone

            if isDrop && isIndex! {
                return true
            }
        }

        return false
    }


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        if  let            zone = widgetZone, isInnerDot {
            let  showAsBookmark = zone.isBookmark || zone.isRootOfFavorites
            isHidden            = isToggle && !(zone.hasChildren      || showAsBookmark || isDragTarget)
            let shouldHighlight = isToggle   ? (zone.indicateChildren || showAsBookmark || isDragTarget) : zone.isSelected
            let     strokeColor = isDragTarget ? gDragTargetsColor     : showAsBookmark  ? gBookmarkColor : gZoneColor
            let       fillColor = shouldHighlight ? strokeColor : gBackgroundColor
            let       thickness = CGFloat(gLineThickness)
            let            path = ZBezierPath(ovalIn: dirtyRect.insetBy(dx: thickness, dy: thickness))

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
                gSelectionManager.draggedZone = nil
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


    func singleEvent(_ iGesture: ZGestureRecognizer?) {
        if isToggle {
            gEditingManager.toggleDotActionOnZone(widgetZone)
        } else {
            widgetZone?.grab()
        }
    }


    func dragEvent(_ iGesture: ZGestureRecognizer?) {
        let isHere = widgetZone == gHere

        if iGesture?.state == .began {
            gSelectionManager.deselect()
            widgetZone?.grab()

            if !isHere {
                gSelectionManager.draggedZone = widgetZone
            }
        }

        if !isHere {
            gEditor?.handleDragEvent(iGesture)
        }
    }
}
