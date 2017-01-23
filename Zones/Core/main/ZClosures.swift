//
//  XBClosures.h
//  XIMBLE
//
//  Created by Jonathan Sand on 3/9/16.
//  Copyright © 2016 Xicato. All rights reserved.
//


import Foundation;
import CloudKit


typealias Closure                 = ()          -> (Void)
typealias ZoneClosure             = (Zone)      -> (Void)
typealias ViewClosure             = (ZView)     -> (Void)
typealias TimerClosure            = (Timer)     -> (ObjCBool)
typealias ObjectClosure           = (NSObject)  -> (Void)
typealias RecordClosure           = (CKRecord?) -> (Void)
typealias ClosureClosure          = (Closure)   -> (Void)
typealias IntegerClosure          = (Int)       -> (Void)
typealias BooleanClosure          = (Bool)      -> ()
typealias ToObjectClosure         = (Void)      -> (NSObject)
typealias ToBooleanClosure        = ()          -> (Bool)
typealias ZoneToBooleanClosure    = (Zone)      -> (Bool)
typealias ObjectToObjectClosure   = (NSObject)  -> (NSObject)
typealias ObjectToStringClosure   = (NSObject)  -> (String)
typealias BooleanToBooleanClosure = (ObjCBool)  -> (ObjCBool)
typealias StateRecordClosure      = (ZRecordState, ZRecord) -> (Void)
typealias SignalClosure           = (Any?,     ZSignalKind) -> (Void)
