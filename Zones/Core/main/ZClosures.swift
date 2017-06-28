//
//  XBClosures.h
//  Zones
//
//  Created by Jonathan Sand on 3/9/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation;
import CloudKit


enum ZTraverseStatus: Int {
    case eContinue
    case eSkip
    case eStop
}


typealias Closure                 = ()                                -> (Void)
typealias ZoneClosure             = (Zone)                            -> (Void)
typealias ViewClosure             = (ZView)                           -> (Void)
typealias TimerClosure            = (Timer)                           -> (ObjCBool)
typealias ObjectClosure           = (NSObject?)                       -> (Void)
typealias RecordClosure           = (CKRecord?)                       -> (Void)
typealias SignalClosure           = (Any?,               ZSignalKind) -> (Void)
typealias ClosureClosure          = (Closure)                         -> (Void)
typealias IntegerClosure          = (Int)                             -> (Void)
typealias BooleanClosure          = (Bool)                            -> ()
typealias ToObjectClosure         = (Void)                            -> (NSObject)
typealias ToBooleanClosure        = ()                                -> (Bool)
typealias ZoneMaybeClosure        = (Zone?)                           -> (Void)
typealias ZoneBooleanClosure      = (Zone,                      Bool) -> (Void)
typealias StateRecordClosure      = (ZRecordState,           ZRecord) -> (Void)
typealias ZoneToStatusClosure     = (Zone)                            -> (ZTraverseStatus)
typealias DotToBooleanClosure     = (ZoneDot)                         -> (Bool)
typealias ModeAndSignalClosure    = (Any?, ZStorageMode, ZSignalKind) -> (Void)
typealias ObjectToObjectClosure   = (NSObject)                        -> (NSObject)
typealias ObjectToStringClosure   = (NSObject)                        -> (String)
typealias BooleanToBooleanClosure = (ObjCBool)                        -> (ObjCBool)
