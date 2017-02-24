//
//  ZoneWidget.swift
//  Zones
//
//  Created by Jonathan Sand on 10/7/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZLineKind: Int {
    case below    = -1
    case straight =  0
    case above    =  1
}


let dragTarget = false


class ZoneWidget: ZView {


    private var       _textWidget:  ZoneTextWidget!
    private var     _childrenView:  ZView!
    private var   childrenWidgets = [ZoneWidget] ()
    let                 toggleDot = ZoneDot ()
    let                   dragDot = ZoneDot ()
    var                widgetZone:  Zone!
    var               hasChildren:  Bool { return widgetZone.hasChildren || widgetZone.count > 0 }
    var           needsSecondDraw = true


    var controllerView: ZView {
        return gControllersManager.controllerForID(.editor)?.view ?? self
    }


    var textWidget: ZoneTextWidget {
        if _textWidget == nil {
            _textWidget = ZoneTextWidget()

            _textWidget.setup()
            addSubview(_textWidget)

            _textWidget.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                make.width.equalTo(200.0)
            }

            snp.makeConstraints { (make: ConstraintMaker) -> Void in
                make.centerY.equalTo(_textWidget).offset(1.5)
                make.size.greaterThanOrEqualTo(_textWidget)
            }
        }

        return _textWidget
    }


    var childrenView: ZView {
        if  _childrenView == nil {
            _childrenView  = ZView()

            addSubview(_childrenView)

            _childrenView.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                make.top.bottom.right.equalTo(self)
            }
        }

        return _childrenView
    }


    deinit {
        childrenWidgets.removeAll()

        _childrenView = nil
        _textWidget   = nil
        widgetZone    = nil
    }


    // MARK:- layout
    // MARK:-


    func layoutInView(_ inView: ZView?, atIndex: Int?, recursing: Bool, kind: ZSignalKind) {
        if inView != nil && !(inView?.subviews.contains(self))! {
            inView?.addSubview(self)

            if atIndex == nil {
                snp.remakeConstraints { (make: ConstraintMaker) -> Void in
                    make.center.equalTo(inView!)
                }
            }
        }

        inView?.zlayer.backgroundColor = ZColor.clear.cgColor
        needsSecondDraw                = true

        clear()
        gWidgetsManager.registerWidget(self)

        if recursing {
            prepareChildren()
            layoutChildren(kind)
        }

        layoutText()
        layoutDots()
    }


    func layoutText() {
        textWidget.widget = self
        textWidget.font   = widgetZone.isSelected ? gGrabbedWidgetFont : gWidgetFont

        textWidget.updateText()
        layoutTextField()
    }


    func layoutTextField() {
        textWidget.snp.removeConstraints()
        textWidget.snp.makeConstraints { (make: ConstraintMaker) -> Void in
            let  font = widgetZone.isSelected ? gGrabbedWidgetFont : gWidgetFont
            let width = textWidget.text!.widthForFont(font) + 5.0

            make  .width.equalTo(width)
            make.centerY.equalTo(self).offset(-1.5)
            make   .left.equalTo(self).offset(Double(gGenericOffset.width))
            make  .right.lessThanOrEqualTo(self).offset(-29.0)
            make .height.lessThanOrEqualTo(self).offset(-gGenericOffset.height)

            if hasChildren {
                make.right.equalTo(childrenView.snp.left).offset(-8.0)
            }
        }
    }


    func prepareChildren() {
        if !widgetZone.includeChildren {
            for child in childrenWidgets {
                gWidgetsManager.unregisterWidget(child)
            }

            childrenWidgets.removeAll()

            if _childrenView != nil {
                for view in _childrenView.subviews {
                    view.removeFromSuperview()
                }

                _childrenView.removeFromSuperview()

                _childrenView = nil
            }
        } else {
            for (_, child) in childrenWidgets.enumerated() {
                if !widgetZone.children.contains(child.widgetZone) {
                    gWidgetsManager.unregisterWidget(child)
                    child.removeFromSuperview()

                    if let index = childrenWidgets.index(of: child) {
                        childrenWidgets.remove(at: index)
                    }
                }
            }

            while childrenWidgets.count < widgetZone.count {
                childrenWidgets.append(ZoneWidget())
            }
        }
    }


    func layoutChildren(_ kind: ZSignalKind) {
        if widgetZone.includeChildren {
            var            index = widgetZone.count
            var previous: ZView? = nil

            while index > 0 {
                index                 -= 1 // go backwards down the arrays, constraint making expects it, below
                let childWidget        = childrenWidgets[index]
                childWidget.widgetZone = widgetZone     [index]

                childWidget.layoutInView(childrenView, atIndex: index, recursing: true, kind: kind)
                childWidget.snp.removeConstraints()
                childWidget.snp.makeConstraints { (make: ConstraintMaker) in
                    if previous != nil {
                        make.bottom.equalTo((previous?.snp.top)!)
                    } else {
                        make.bottom.equalTo(childrenView)
                    }

                    if index == 0 {
                        make.top.equalTo(childrenView)
                    }

                    make.left.equalTo(childrenView)
                    make.right.height.lessThanOrEqualTo(childrenView)
                }

                previous = childWidget
            }
        }
    }


    func layoutDots() {
        if !subviews.contains(dragDot) {
            addSubview(dragDot)
        }

        if widgetZone.parentZone?.zoneName == "bugs" && widgetZone.zoneName == "drag and toggle dots not aligned" {
            report("layoutDots")
        }

        dragDot.innerDot?.snp.removeConstraints()
        dragDot.setupForWidget(self, asToggle: false)
        dragDot.innerDot?.snp.makeConstraints { (make: ConstraintMaker) in
            make.right.equalTo(textWidget.snp.left)
            make.centerY.equalTo(textWidget).offset(1.5)
        }

        if !subviews.contains(toggleDot) {
            addSubview(toggleDot)
        }

        toggleDot.innerDot?.snp.removeConstraints()
        toggleDot.setupForWidget(self, asToggle: true)
        toggleDot.innerDot?.snp.makeConstraints { (make: ConstraintMaker) in
            make.left.equalTo(textWidget.snp.right).offset(-1.0)
            make.centerY.equalTo(textWidget).offset(1.5)
            make.right.lessThanOrEqualToSuperview().offset(-1.0)
        }
    }


    // MARK:- drag
    // MARK:-


    func displayForDrag() {
        toggleDot        .innerDot?.setNeedsDisplay()
        self                       .setNeedsDisplay()

        for child in childrenWidgets {
            child.dragDot.innerDot?.setNeedsDisplay()
            child                  .setNeedsDisplay()
        }
    }


    var dragTargetFrame: CGRect {
        let isHere = widgetZone == gHere
        let cFrame = convert(childrenView.frame, to: controllerView)
        let  right =                                                   controllerView.bounds .maxX
        let    top = ((!isHere && widgetZone.hasZonesAbove) ? cFrame : controllerView.bounds).maxY
        let bottom =  (!isHere && widgetZone.hasZonesBelow) ? cFrame.minY : 0.0
        let   left =    isHere ? 0.0 : convert(dragDot.innerDot!.frame, to: controllerView).minX
        let result = CGRect(x: left, y: bottom, width: right - left, height: top - bottom)

        return result
    }


    func dragContainsPoint(_ iPoint: CGPoint) -> Bool {
        let rect = dragTargetFrame

        return rect.minX <= iPoint.x && rect.minY <= iPoint.y && rect.maxY >= iPoint.y
    }


    func widgetNearestTo(_ iPoint: CGPoint, in iView: ZView) -> ZoneWidget? {
        if dragContainsPoint(iPoint) && !widgetZone.isProgenyOf(gSelectionManager.zoneBeingDragged!) {
            if widgetZone.showChildren {
                for child in widgetZone.children {
                    if let childWidget = gWidgetsManager.widgetForZone(child), let found = childWidget.widgetNearestTo(iPoint, in: self) {
                        return found
                    }
                }
            }

            return self
        }

        return nil
    }


    func isDropIndex(_ iIndex: Int?) -> Bool {
        if  iIndex != nil {
            let isIndex = gSelectionManager.targetLineIndices?.contains(iIndex!)
            let  isDrop = widgetZone == gSelectionManager.targetDropZone

            if isDrop && isIndex! {
                return true
            }
        }

        return false
    }
    

    // MARK:- draw
    // MARK:-


    func lineKindOf(_ widget: ZoneWidget?) -> ZLineKind {
        if  widgetZone.count > 1 {
            let           dragDot = widget?.dragDot.innerDot
            let    dragDotCenterY =   dragDot?.convert((  dragDot?.bounds)!, to: self).center.y
            let textWidgetCenterY = textWidget.convert((textWidget.bounds),  to: self).center.y
            let             delta = Double(dragDotCenterY! - textWidgetCenterY)
            let         threshold = gDotHeight / 2.0

            if delta > threshold {
                return .above
            } else if delta < -threshold {
                return .below
            }
        }

        return .straight
    }


    func rectForLine(to rightWidget: ZoneWidget?) -> CGRect {
        var frame = CGRect ()

        if  rightWidget          != nil, let leftDot = toggleDot.innerDot, let rightDot = rightWidget!.dragDot.innerDot {
            let         leftFrame =  leftDot.convert( leftDot.bounds, to: self)
            let        rightFrame = rightDot.convert(rightDot.bounds, to: self)
            let         thickness = CGFloat(gLineThickness)
            let     halfDotHeight = CGFloat(gDotHeight / 2.0)
            let     thinThickness = thickness / 2.0
            let         rightMidY = rightFrame.midY
            let          leftMidY = leftFrame .midY
            frame.origin       .x = leftFrame .midX

            switch lineKindOf(rightWidget) {
            case .above:
                frame.origin   .y = leftFrame .maxY - thinThickness
                frame.size.height = fabs( rightMidY + thinThickness - frame.minY)
            case .below:
                frame.origin   .y = rightFrame.minY
                frame.size.height = fabs(  leftMidY + thinThickness - frame.minY - halfDotHeight)
            case .straight:
                frame.origin   .y =       rightMidY - thinThickness / 8.0
                frame.origin   .x = leftFrame .maxX
                frame.size.height =                   thinThickness / 4.0
            }

            frame.size     .width = fabs(rightFrame.minX - frame.minX)
        }
        
        return frame
    }


    func drawLine(to child: ZoneWidget) {
        let      lineThickness = CGFloat(gLineThickness)
        let      halfDotHeight = CGFloat(gDotHeight / 2.0)
        let       halfDotWidth = CGFloat(gDotWidth  / 2.0)
        let         strokeRect = rectForLine(to: child)
        var               path = ZBezierPath(rect: strokeRect)
        let               kind = lineKindOf(child)

        if kind == .straight {
            ZBezierPath(rect: bounds).setClip()
        } else {
            ZColor.clear.setFill()
            path.setClip()

            var           rect = strokeRect

            if kind == .below {
                rect.origin.y += halfDotHeight
            } else {
                rect.origin.y -= rect.size.height       + lineThickness
            }

            rect.size   .width = rect.size.width  * 2.0 + halfDotWidth
            rect.size  .height = rect.size.height * 2.0 + lineThickness
            path               = ZBezierPath(ovalIn: rect)
        }

        let               zone = child.widgetZone!
        let              color = zone.isBookmark ? gBookmarkColor : isDropIndex(zone.siblingIndex) ? gDragTargetsColor : gZoneColor
        path        .lineWidth = lineThickness
        path         .flatness = 0.0001

        color.setStroke()
        path.stroke()
    }


    func drawDragHighlight() {
        let     thickness = dragDot.width / 2.5
        var          rect = textWidget.frame.insetBy(dx: -13.0, dy: 0.0)
        rect.size .width += 1.0
        rect.size.height -= 3.0
        let        radius = min(rect.size.height, rect.size.width) / 2.08 - 1.0
        let         color = widgetZone.isBookmark ? gBookmarkColor : gZoneColor
        let     fillColor = color.withAlphaComponent(0.02)
        let   strokeColor = color.withAlphaComponent(0.2)
        let          path = ZBezierPath(roundedRect: rect, cornerRadius: radius)
        path   .lineWidth = thickness
        path    .flatness = 0.0001

        fillColor.setFill()
        strokeColor.setStroke()
        path.stroke()
    }


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        if widgetZone.zoneName == "bugs" {
            report("draw lines")
        }

        let        isGrabbed = widgetZone.isGrabbed
        textWidget.textColor = isGrabbed ? widgetZone.isBookmark ? grabbedBookmarkColor : grabbedTextColor : ZColor.black

        if isGrabbed && !widgetZone.isEditing {
            drawDragHighlight()
        }

        for child in childrenWidgets {
            drawLine(to: child)
        }

        if           needsSecondDraw {
            dispatchAsyncInForeground {
                self.needsSecondDraw = false

                self.setNeedsDisplay()
            }
        }
    }
}
