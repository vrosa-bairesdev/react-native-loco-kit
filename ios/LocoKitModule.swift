//
//  LocoKitComponent.swift
//  react-native-loco-kit
//
//  Created by Vin Rosa on 1/25/22.
//

import Foundation

import LocoKit
import Foundation
import SwiftNotes
import BackgroundTasks
import CoreLocation
import React

enum EventTypes: String {
    case locationStatusEvent = "LocationStatusEvent"
    case timeLineStatusEvent = "TimeLineStatusEvent"
    case activityTypeEvent = "ActivityTypeEvent"
}

@objc(LocoKitModule)
class LocoKitModule: RCTEventEmitter  {
    
    private var store    : TimelineStore?
    private var recorder : TimelineRecorder?
    
    @objc(setup:callback:)
    func setup(_ key: String, callback:(([Any]) -> Void)) -> Void {
        DispatchQueue.main.sync {
            LocoKitService.apiKey = key
            store = TimelineStore()
            if let store = store {
                if LocoKitService.apiKey?.isEmpty ?? true {
                    recorder = TimelineRecorder(store: store);
                    callback(["Missing API KEY"])
                }else {
                    ActivityTypesCache.highlander.store = store
                    recorder = TimelineRecorder(store: store, classifier: TimelineClassifier.highlander)
                    recorder?.samplesPerMinute = 1
                    callback(["OK"])
                }
                LocomotionManager.highlander.locationManager.requestAlwaysAuthorization()
                
                if #available(iOS 14.0, *) {
                    sendEvent(
                        withName: EventTypes.locationStatusEvent.rawValue,
                        body: LocomotionManager.highlander.locationManager.authorizationStatus.rawValue
                    )
                } else {
                    sendEvent(
                        withName: EventTypes.locationStatusEvent.rawValue,
                        body: "Unknown"
                    )
                }
            }
        }
    }
    
    override func supportedEvents() -> [String]! {
        return [EventTypes.locationStatusEvent, EventTypes.timeLineStatusEvent, EventTypes.activityTypeEvent].map { e in
            e.rawValue
        };
    }
    
    @objc
    func start() -> Void{
        print("LocoKit.start()")
        guard let recorder = self.recorder else {
            return
        }
        
        
        if !recorder.isRecording {
            recorder.startRecording()
            when(.newTimelineItem) { _ in
                if let currentItem = recorder.currentItem {
                    self.registerTimelineItem(item: currentItem)
                }
            }
            when(.updatedTimelineItem) { _ in
                if let currentItem = recorder.currentItem {
                    self.registerTimelineItem(item: currentItem)
                }
            }
            
            //            let loco = LocomotionManager.highlander
            var loco: LocomotionManager { return LocomotionManager.highlander }
            loco.locationManager.startMonitoringSignificantLocationChanges()
            loco.locationManager.startMonitoringVisits()
            loco.startCoreMotion()
            // observe changes in the recording state (recording / sleeping)
            when(loco, does: .recordingStateChanged) { _ in
                // don't log every type of state change, because it gets noisy
                if loco.recordingState == .recording || loco.recordingState == .off {
                    print(".recordingStateChanged (\(loco.recordingState))")
                }
            }
            
            when(loco, does: .didChangeAuthorizationStatus) { [weak self] notification in
                if let userInfo = notification.userInfo as? [String:Any] {
                    if let status = userInfo["status"] as? CLAuthorizationStatus {
                        print(".didChangeAuthorizationStatus \(status)")
                        switch status {
                        case .notDetermined:
                            self?.registerLocationStatus("Not Determined")
                            break
                        case .restricted:
                            self?.registerLocationStatus("Restricted")
                            break
                        case .denied:
                            self?.registerLocationStatus("Denied")
                            break
                        case .authorizedAlways:
                            self?.registerLocationStatus("Authorized Always")
                            break
                        case .authorizedWhenInUse:
                            self?.registerLocationStatus("Authorized When In Use")
                            break
                        case .authorized:
                            self?.registerLocationStatus("Authorized")
                            break
                        }
                    }
                }
            }
            
            // observe changes in the moving state (moving / stationary)
            when(loco, does: .movingStateChanged) { _ in
                print(".movingStateChanged (\(loco.movingState))")
                self.sendEvent(withName: EventTypes.activityTypeEvent.rawValue, body: loco.movingState.rawValue)
            }
            
            when(loco, does: .wentFromRecordingToSleepMode) { _ in
                print(".startedSleepMode")
            }
            
            when(loco, does: .wentFromSleepModeToRecording) { _ in
                print(".stoppedSleepMode")
            }
        }
    }
    
    func registerLocationStatus(_ status: String) -> Void {
        self.sendEvent(withName: EventTypes.locationStatusEvent.rawValue, body: status)
    }
    
    func stop () -> Void {
        print("LocoKit.stop()")
        guard let recorder = recorder else {
            return
        }
        
        if recorder.isRecording {
            recorder.stopRecording()
        }
    }
    
    func registerTimelineItem(item: TimelineItem,  onCompletion: ((Bool, Error?) -> Void)? = nil) {
        if item.isWorthKeeping {
            var results:Dictionary<String, Any>
            if let classifierResults =  item.classifierResults {
                results = [
                    "best": [
                        "name": classifierResults.best.name.displayName,
                        "modelAccuracyScore": classifierResults.best.modelAccuracyScore ?? 0,
                        "score": classifierResults.best.score
                    ]
                ]
            } else {
                results = [:]
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            
            var rpath: Dictionary<String, Any> = [:]
            if let path = item as? Path {
                rpath = [
                    "distance": path.distance,
                    "speed": path.metresPerSecond,
                    "kph": path.kph,
                    "activityType": path.activityType?.displayName ?? "Unknown",
                ]
            }
            var rvisit: Dictionary<String, Any> = [:]
            if let visit = item as? Visit {
                rvisit = [
                    "radius": visit.radius2sd,
                    "duration": visit.duration,
                    "latitude": visit.center?.coordinate.latitude ?? 0.0,
                    "longitude": visit.center?.coordinate.longitude ?? 0.0,
                    "activityType": visit.activityType?.displayName ?? "Unknown"
                ]
            }
            
            var sampleResult: [[String: Any]] = []
            
            for sample in item.samples{
                let date = sample.date
                let latitude = sample.location?.coordinate.latitude ?? nil
                let longitude = sample.location?.coordinate.longitude ?? nil
                let courseVariance = sample.courseVariance ?? 0
                let stepHz = sample.stepHz ?? 0
                let activityType:String = sample.activityType?.displayName ?? "Unknown"
                
                sampleResult.append([
                    "date": dateFormatter.string(from: date),
                    "coordinates": [latitude, longitude],
                    "courseVariance": courseVariance,
                    "stepHz": stepHz,
                    "activityType": activityType,
                ])
                print("sample: \(sampleResult)")
            }
            
            let floorsAsc:Int = item.floorsAscended ?? 0
            let floorsDsc:Int = item.floorsDescended ?? 0
            
            let data:[String: Any] = [
                "keepnessScore": item.keepnessScore,
                "classifierResults": results,
                "altitude": item.altitude ?? -1,
                "floorsAscended": floorsAsc,
                "floorsDescended": floorsDsc,
                "samples": sampleResult,
                "dateRange": [
                    "start" : dateFormatter.string(from: item.dateRange?.start ?? Date(timeIntervalSince1970:0)),
                    "end": dateFormatter.string(from: item.dateRange?.end ?? Date(timeIntervalSince1970:0))
                ],
                "dateRangeQueryable": [
                    "start" : item.dateRange?.start,
                    "end":  item.dateRange?.end
                ],
                "path": rpath,
                "visit": rvisit,
            ]
            self.sendEvent(withName: EventTypes.timeLineStatusEvent.rawValue, body: String(describing: data))
        }
    }
    
}
