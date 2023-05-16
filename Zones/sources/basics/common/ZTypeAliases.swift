//
//  ZTypeAliases.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/15/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

typealias                CKRecordID = CKRecord.ID
typealias               CKReference = CKRecord.Reference
typealias          ZStoryboardSegue = NSStoryboardSegue

typealias                 ZoneArray = [Zone]
typealias               ZOpIDsArray = [ZOperationID]
typealias               ZFilesArray = [ZFile]
typealias               ZTraitArray = [ZTrait]
typealias              StringsArray = [String]
typealias             CKAssetsArray = [CKAsset]
typealias             ZRecordsArray = [ZRecord]
typealias             ZObjectsArray = [NSObject]
typealias            CKRecordsArray = [CKRecord]
typealias           ZoneWidgetArray = [ZoneWidget]
typealias           ZObjectIDsArray = [NSManagedObjectID]
typealias          CKRecordIDsArray = [CKRecordID]
typealias          ZTraitTypesArray = [ZTraitType]
typealias          ZSignalKindArray = [ZSignalKind]
typealias          ZDatabaseIDArray = [ZDatabaseID]
typealias         CKReferencesArray = [CKReference]
typealias         ZTinyDotTypeArray = [[ZTinyDotType]]
typealias        ZRelationshipArray = [ZRelationship]
typealias      ZManagedObjectsArray = [NSManagedObject]

typealias          ZTraitDictionary = [ZTraitType   : ZTrait]
typealias         ZAssetsDictionary = [UUID         : CKAsset]
typealias        ZStorageDictionary = [ZStorageType : NSObject]
typealias      WidgetHashDictionary = [Int          : ZoneWidget]
typealias  ZRelationshipsDictionary = [Int          : ZRelationshipArray]
typealias      ZStringAnyDictionary = [String       : Any]
typealias   StringZRecordDictionary = [String       : ZRecord]
typealias   ZStringObjectDictionary = [String       : NSObject]
typealias ZManagedObjectsDictionary = [String       : ZManagedObject]
typealias  StringZRecordsDictionary = [String       : ZRecordsArray]
typealias    ZDBIDRecordsDictionary = [ZDatabaseID  : ZRecordsArray]
typealias     ZAttributesDictionary = [NSAttributedString.Key : Any]

#if os(OSX)

public typealias ZBox                        = NSBox
public typealias ZFont                       = NSFont
public typealias ZView                       = NSView
public typealias ZMenu                       = NSMenu
public typealias ZAlert                      = NSAlert
public typealias ZEvent                      = NSEvent
public typealias ZImage                      = NSImage
public typealias ZColor                      = NSColor
public typealias ZButton                     = NSButton
public typealias ZSlider                     = NSSlider
public typealias ZWindow                     = NSWindow
public typealias ZControl                    = NSControl
public typealias ZMenuItem                   = NSMenuItem
public typealias ZClipView                   = NSClipView
public typealias ZTextView                   = NSTextView
public typealias ZTextField                  = NSTextField
public typealias ZTableView                  = NSTableView
public typealias ZStackView                  = NSStackView
public typealias ZImageView                  = NSImageView
public typealias ZColorWell                  = NSColorWell
public typealias ZEventType                  = ZEvent.EventType
public typealias ZButtonCell                 = NSButtonCell
public typealias ZBezierPath                 = NSBezierPath
public typealias ZScrollView                 = NSScrollView
public typealias ZController                 = NSViewController
public typealias ZToolTipTag                 = ZView.ToolTipTag
public typealias ZEventFlags                 = ZEvent.ModifierFlags
public typealias ZSearchField                = NSSearchField
public typealias ZTableColumn                = NSTableColumn
public typealias ZTableRowView               = NSTableRowView
public typealias ZMenuDelegate               = NSMenuDelegate
public typealias ZTableCellView              = NSTableCellView
public typealias ZBitmapImageRep             = NSBitmapImageRep
public typealias ZWindowDelegate             = NSWindowDelegate
public typealias ZFontDescriptor             = NSFontDescriptor
public typealias ZWindowController           = NSWindowController
public typealias ZSegmentedControl           = NSSegmentedControl
public typealias ZTextViewDelegate           = NSTextViewDelegate
public typealias ZTextFieldDelegate          = NSTextFieldDelegate
public typealias ZGestureRecognizer          = NSGestureRecognizer
public typealias ZProgressIndicator          = NSProgressIndicator
public typealias ZTableViewDelegate          = NSTableViewDelegate
public typealias ZTableViewDataSource        = NSTableViewDataSource
public typealias ZSearchFieldDelegate        = NSSearchFieldDelegate
public typealias ZApplicationDelegate        = NSApplicationDelegate
public typealias ZClickGestureRecognizer     = NSClickGestureRecognizer
public typealias ZGestureRecognizerState     = NSGestureRecognizer.State
public typealias ZGestureRecognizerDelegate  = NSGestureRecognizerDelegate
public typealias ZEdgeSwipeGestureRecognizer = NSNull

#elseif os(iOS)

public typealias ZFont                       = UIFont
public typealias ZView                       = UIView
public typealias ZAlert                      = UIAlertController
public typealias ZImage                      = UIImage
public typealias ZColor                      = UIColor
public typealias ZEvent                      = UIKeyCommand
public typealias ZButton                     = UIButton
public typealias ZWindow                     = UIWindow
public typealias ZSlider                     = UISlider
public typealias ZControl                    = UIControl
public typealias ZMenuItem                   = UIMenuItem
public typealias ZTextView                   = UITextView
public typealias ZTextField                  = UITextField
public typealias ZStackView                  = UIStackView
public typealias ZTableView                  = UITableView
public typealias ZScrollView                 = UIScrollView
public typealias ZController                 = UIViewController
public typealias ZEventFlags                 = UIKeyModifierFlags
public typealias ZBezierPath                 = UIBezierPath
public typealias ZSearchField                = UISearchBar
public typealias ZApplication                = UIApplication
public typealias ZTableColumn                = ZNullProtocol
public typealias ZWindowDelegate             = ZNullProtocol
public typealias ZScrollDelegate             = UIScrollViewDelegate
public typealias ZWindowController           = ZNullProtocol
public typealias ZSegmentedControl           = UISegmentedControl
public typealias ZGestureRecognizer          = UIGestureRecognizer
public typealias ZProgressIndicator          = UIActivityIndicatorView
public typealias ZTextFieldDelegate          = UITextFieldDelegate
public typealias ZTableViewDelegate          = UITableViewDelegate
public typealias ZSearchFieldDelegate        = UISearchBarDelegate
public typealias ZTableViewDataSource        = UITableViewDataSource
public typealias ZApplicationDelegate        = UIApplicationDelegate
public typealias ZPanGestureRecognizer       = UIPanGestureRecognizer
public typealias ZClickGestureRecognizer     = UITapGestureRecognizer
public typealias ZSwipeGestureRecognizer     = UISwipeGestureRecognizer
public typealias ZGestureRecognizerState     = UIGestureRecognizer.State
public typealias ZGestureRecognizerDelegate  = UIGestureRecognizerDelegate
public typealias ZEdgeSwipeGestureRecognizer = UIScreenEdgePanGestureRecognizer

#endif
