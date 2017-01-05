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


class ZoneWidget: ZView {


    private var       _textWidget: ZoneTextWidget!
    private var     _childrenView: ZView!
    private let dragHighlightView = ZView()
    private var   childrenWidgets = [ZoneWidget?] ()
    private var      siblingLines = [ZoneCurve] ()
    let                 toggleDot = ZoneDot()
    let                   dragDot = ZoneDot()
    var                widgetZone: Zone!


    var hasChildren: Bool {
        get { return widgetZone.hasChildren || widgetZone.children.count > 0 }
    }


    var textWidget: ZoneTextWidget {
        get {
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
    }


    var childrenView: ZView {
        get {
            if _childrenView == nil {
                _childrenView = ZView()

                addSubview(_childrenView)

                _childrenView.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                    make.top.bottom.right.equalTo(self)
                }
            }

            return _childrenView
        }
    }


    deinit {
        childrenWidgets.removeAll()

        _childrenView = nil
        _textWidget   = nil
        widgetZone    = nil
}


    // MARK:- layout
    // MARK:-


    func layoutInView(_ inView: ZView?, atIndex: Int, recursing: Bool, kind: ZSignalKind) {
        if inView != nil && !(inView?.subviews.contains(self))! {
            inView?.addSubview(self)

            if atIndex == -1 {
                snp.remakeConstraints { (make: ConstraintMaker) -> Void in
                    make.center.equalTo(inView!)
                }
            }
        }

        inView?.zlayer.backgroundColor = ZColor.clear.cgColor

        clear()
        widgetsManager.registerWidget(self)
        addDragHighlight()

        if recursing {
            layoutChildren(kind)
            layoutLines(kind)
        }

        layoutText()
        layoutDots()
        layoutDragHighlight()
    }


    func layoutFinish() {
        layoutDecorations()

        for widget in childrenWidgets {
            widget?.layoutFinish()
        }
    }


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        dispatchAsyncInForeground {
            let                                    radius = min(dirtyRect.size.height, dirtyRect.size.width) / 2.0
            let                             color: ZColor = self.widgetZone.isBookmark ? gBookmarkColor : gZoneColor
            self.dragHighlightView.zlayer.backgroundColor = color.withAlphaComponent(0.008).cgColor

            self.dragHighlightView.addBorder(thickness: 0.15, radius: radius, color: color.cgColor)
        }
    }


    func layoutDecorations() {
        // self        .addBorderRelative(thickness: 1.0, radius: 0.5, color: ZColor.green.cgColor)
        // textWidget.addBorder(thickness: 5.0, radius: 0.5, color: CGColor.black)

//        let  show = selectionManager.isGrabbed(widgetZone) && widgetZone.children.count > 0 && widgetZone.showChildren
//        let color = show ? ZColor.orange : ZColor.clear
//
//        childrenView.addBorder(thickness: 1.0, radius: 10.0, color: color.cgColor)
    }


    func addDragHighlight() {
        dragHighlightView.isHidden = !selectionManager.isGrabbed(widgetZone)

        if dragHighlightView.superview == nil {
            addSubview(dragHighlightView)
        }
    }


    func layoutDragHighlight() {
        dragHighlightView.snp.makeConstraints({ (make: ConstraintMaker) in
            make.top.bottom.equalTo(self)
            make.right.equalTo(self).offset(-10.0)
            make.left.equalTo(self).offset(gDotHeight / 1.75)
        })
    }


    func layoutText() {
        textWidget.widget    = self
        let       isSelected = selectionManager.isSelected(widgetZone)
        textWidget.font      = isSelected ? grabbedWidgetFont : widgetFont
        textWidget.textColor = isSelected ? widgetZone.isBookmark ? grabbedBookmarkColor : grabbedTextColor : ZColor.black

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
            let isSelected = selectionManager.isSelected(widgetZone)
            let       font = isSelected ? grabbedWidgetFont : widgetFont
            let      width = textWidget.text!.widthForFont(font) + 5.0

            make.width.equalTo(width)
            make.centerY.equalTo(self).offset(-1.5)
            make.right.lessThanOrEqualTo(self).offset(-29.0)
            make.left.equalTo(self).offset(Double(gGenericOffset.width))
            make.height.lessThanOrEqualTo(self).offset(-gGenericOffset.height)

            if hasChildren {
                make.right.equalTo(childrenView.snp.left).offset(-20.0)
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
        let zoneChildrenCount = widgetZone.children.count

        if _childrenView != nil {
            if  childrenWidgets.count != zoneChildrenCount || !widgetZone.showChildren || zoneChildrenCount == 0 {
                childrenWidgets.removeAll()
                clearChildrenView()

                _childrenView = nil
            }
        }

        if zoneChildrenCount > 0 && widgetZone.showChildren {
            while childrenWidgets.count < zoneChildrenCount {
                childrenWidgets.append(ZoneWidget())
            }

            var            index = zoneChildrenCount
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
                    childWidget?.snp.makeConstraints({ (make: ConstraintMaker) in
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
                    })

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

                        siblingLine.snp.makeConstraints({ (make: ConstraintMaker) in
                            make.width.height.equalTo(gLineThickness)
                            make.centerX.equalTo(textWidget.snp.right).offset(6.0)
                            make.centerY.equalTo(textWidget)
                        })
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
        dragDot.setupForZone(widgetZone, asToggle: false)
        dragDot.innerDot?.snp.makeConstraints({ (make: ConstraintMaker) in
            make.right.equalTo(textWidget.snp.left)
            make.centerY.equalTo(textWidget).offset(1.0)
        })

        if !hasChildren && !widgetZone.isBookmark {
            if subviews.contains(toggleDot) {
                toggleDot.removeFromSuperview()
            }
        } else {
            if !subviews.contains(toggleDot) {
                addSubview(toggleDot)
            }

            toggleDot.innerDot?.snp.removeConstraints()
            toggleDot.setupForZone(widgetZone, asToggle: true)
            toggleDot.innerDot?.snp.makeConstraints({ (make: ConstraintMaker) in
                make.left.equalTo(textWidget.snp.right).offset(-1.0)
                make.centerY.equalTo(textWidget).offset(1.0)
                make.right.lessThanOrEqualToSuperview().offset(-1.0)
            })
        }
    }
}
