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


let dragTarget = false


class ZoneWidget: ZView {


    private var       _textWidget:  ZoneTextWidget!
    private var     _childrenView:  ZView!
    private var      siblingLines = [ZoneCurve] ()
    private var   childrenWidgets = [ZoneWidget?] ()
    let                 toggleDot = ZoneDot()
    let                   dragDot = ZoneDot()
    var                widgetZone:  Zone!
    var               hasChildren:  Bool { return widgetZone.hasChildren || widgetZone.count > 0 }


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


    // MARK:- draw
    // MARK:-


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        let        isGrabbed = widgetZone.isGrabbed
        textWidget.textColor = isGrabbed ? widgetZone.isBookmark ? grabbedBookmarkColor : grabbedTextColor : ZColor.black

        if isGrabbed && !widgetZone.isEditing {
            let     thickness = dragDot.width / 2.5
            var          rect = textWidget.frame.insetBy(dx: -13.0, dy: 0.0)
            rect.size .width += 1.0
            rect.size.height -= 3.0
            let        radius = min(rect.size.height, rect.size.width) / 2.08 - 1.0
            let         color = widgetZone.isBookmark ? gBookmarkColor : gZoneColor
            let     fillColor = color.withAlphaComponent(0.02)
            let   strokeColor = color.withAlphaComponent(0.2)
            let          path = ZBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            path   .lineWidth = thickness
            path    .flatness = 0.0001

            fillColor.setFill()
            strokeColor.setStroke()
            path.stroke()
        }
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

        clear()
        gWidgetsManager.registerWidget(self)

        if recursing {
            layoutChildren(kind)
            layoutLines(kind)
        }

        layoutText()
        layoutDots()
    }


    func layoutText() {
        textWidget.widget   = self
        let      isSelected = widgetZone.isSelected
        textWidget.font     = isSelected ? gGrabbedWidgetFont : gWidgetFont

        if textWidget.text == "" && widgetZone.zoneName == nil {
            textWidget.text = "empty"
        } else if widgetZone.zoneName != nil {
            textWidget.text = widgetZone.zoneName
        }

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


    func clearChildrenView() {
        if let view = _childrenView {
            for view in view.subviews {
                view.removeFromSuperview()
            }

            view.removeFromSuperview()
        }
    }


    func layoutChildren(_ kind: ZSignalKind) {
        let count = widgetZone.count

        if (!widgetZone.includeChildren || childrenWidgets.count != count) && _childrenView != nil {
            childrenWidgets.removeAll()
            clearChildrenView()

           _childrenView = nil
        }

        if widgetZone.includeChildren {

            while childrenWidgets.count < count {
                childrenWidgets.append(ZoneWidget())
            }

            var            index = count
            var previous: ZView? = nil

            while index > 0 {
                index          -= 1 // go backwards down the arrays, constraint making expect it, below
                let childZone   = widgetZone     [index]
                let childWidget = childrenWidgets[index]

                if  widgetZone == childZone {
                    childrenWidgets[index] = nil // when?????
                } else {
                    childWidget?.widgetZone = childZone

                    childWidget?.layoutInView(childrenView, atIndex: index, recursing: true, kind: kind)
                    childWidget?.snp.removeConstraints()
                    childWidget?.snp.makeConstraints { (make: ConstraintMaker) in
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

                    childWidget?.layoutText()

                    previous = childWidget
                }
            }
        }
    }


    func layoutLines(_ kind: ZSignalKind) {
        let         show = widgetZone.showChildren
        let  redrawLines = kind == .redraw

        if !show || redrawLines {
            for line in siblingLines {
                line.removeFromSuperview()
            }

            siblingLines.removeAll()
        }

        if show {
            var needUpdate = IndexSet()
            let   children = widgetZone.children
            let      count = children.count

            if count > 0 {
                for index in 0...count - 1 {
                    needUpdate.insert(index)
                }
            }

            for line in siblingLines {
                var found = false

                for (index, child) in children.enumerated() {
                    if show && child == line.child?.widgetZone {
                        if !redrawLines {
                            needUpdate.remove(index)
                        }

                        found = true
                    }
                }

                if !show || !found {
                    line.removeFromSuperview()
                }
            }

            if show && needUpdate.count > 0 {
                for (index, childWidget) in childrenWidgets.enumerated() {
                    if needUpdate.contains(index) {
                        let siblingLine    = ZoneCurve()
                        siblingLine.child  = childWidget
                        siblingLine.parent = self

                        siblingLines.insert(siblingLine, at:index)
                        addSubview(siblingLine)

                        siblingLine.snp.makeConstraints { (make: ConstraintMaker) in
                            make.width.height.equalTo(gLineThickness)
                            make.centerX.equalTo(textWidget.snp.right).offset(6.0)
                            make.centerY.equalTo(textWidget).offset(1.5)
                        }
                    }
                }
            }
        }
    }


    func layoutDots() {
        if !subviews.contains(dragDot) {
            addSubview(dragDot)
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
        toggleDot.innerDot?         .needsDisplay = true

        for line in siblingLines {
            line                    .needsDisplay = true
        }

        for child in childrenWidgets {
            child?.dragDot.innerDot?.needsDisplay = true
        }
    }


    var dragTargetFrame: CGRect {
        let isHere = widgetZone == gTravelManager.hereZone
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
}
