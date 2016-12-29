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
    let               revealerDot = ZoneDot()
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
                    make.centerY.equalTo(_textWidget)
                    make.size.greaterThanOrEqualTo(_textWidget)
                }
            }

            return _textWidget
        }
    }


    var childrenView: ZView {
        get {
            if _childrenView == nil {
                _childrenView                          = ZView()
                _childrenView.isUserInteractionEnabled = false // does nothing in os x

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


    func layoutInView(_ inView: ZView?, atIndex: Int, recursing: Bool) {
        if inView != nil && !(inView?.subviews.contains(self))! {
            inView?.addSubview(self)

            if atIndex == -1 {
                snp.remakeConstraints { (make: ConstraintMaker) -> Void in
                    make.center.equalTo(inView!)
                }
            }
        }

        inView?.zlayer.backgroundColor = ZColor.clear.cgColor
        isUserInteractionEnabled = false

        clear()
        widgetsManager.registerWidget(self)
        addDragHighlight()

        if !recursing {
            // clearChildrenView()
        } else {
            layoutChildren()
            layoutLines()
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
            let                             color: ZColor = self.widgetZone.isBookmark ? bookmarkColor : lineColor
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
            make.left.equalTo(self).offset(8.0)
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
            make.centerY.equalTo(self) // .offset(-1.0)
            make.right.lessThanOrEqualTo(self).offset(-29.0)
            make.left.equalTo(self).offset(dotHeight + Double(genericOffset.width))
            make.height.lessThanOrEqualTo(self).offset(-genericOffset.height)

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


    func layoutChildren() {
        var previous: ZoneWidget? = nil
        var                 index = widgetZone.children.count

        if childrenWidgets.count != index || !widgetZone.showChildren || index == 0 {
            childrenWidgets.removeAll()
            clearChildrenView()

            _childrenView = nil
        }

        if index > 0 && widgetZone.showChildren {
            while childrenWidgets.count < index {
                childrenWidgets.append(ZoneWidget())
            }

            while index > 0 {
                index          -= 1
                let childWidget = childrenWidgets[index]
                let childZone   = widgetZone[index]

                if childZone == widgetZone {
                    childrenWidgets[index] = nil
                } else if childWidget != nil {
                    childWidget?.widgetZone = childZone
                    childWidget?.layoutInView(childrenView, atIndex: index, recursing: true)

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

                        make.left.equalTo(childrenView)//.offset(20.0)
                        make.right.height.lessThanOrEqualTo(childrenView)
                    })
                    
                    childWidget?.layoutText()
                    
                    previous = childWidget
                }
            }
        }
    }


    func layoutLines() {
        for line in siblingLines {
            line.removeFromSuperview()
        }

        siblingLines.removeAll()

        if widgetZone.showChildren {
            var index = widgetZone.children.count
            var siblingLine: ZoneCurve?

            while index > 0 {
                index              -= 1
                let childWidget     = childrenWidgets[index]
                siblingLine         = ZoneCurve()
                siblingLine?.child  = childWidget
                siblingLine?.parent = self

                siblingLines.append(siblingLine!)
                addSubview(siblingLine!)
                siblingLine?.snp.makeConstraints({ (make: ConstraintMaker) in
                    make.width.height.equalTo(lineThicknes)
                    make.centerX.equalTo(textWidget.snp.right).offset(6.0)
                    make.centerY.equalTo(textWidget)
                })
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
            make.centerY.equalTo(textWidget).offset(0.5)
        })

        if !hasChildren && !widgetZone.isBookmark {
            if subviews.contains(revealerDot) {
                revealerDot.removeFromSuperview()
            }
        } else {
            if !subviews.contains(revealerDot) {
                addSubview(revealerDot)
            }

            revealerDot.innerDot?.snp.removeConstraints()
            revealerDot.setupForZone(widgetZone, asToggle: true)
            revealerDot.innerDot?.snp.makeConstraints({ (make: ConstraintMaker) in
                make.left.equalTo(textWidget.snp.right).offset(-1.0)
                make.centerY.equalTo(textWidget).offset(0.5)
                make.right.lessThanOrEqualToSuperview().offset(-1.0)
            })
        }
    }
}
