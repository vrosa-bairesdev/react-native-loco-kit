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
            guard let classifierResults = item.classifierResults else {
                return
            }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            var rpath: DataPath?
            if let path = item as? Path {
                rpath = DataPath(
                    distance: path.distance,
                    speed: path.metresPerSecond,
                    kph: path.kph,
                    activityType:path.activityType?.displayName ?? "Unknown"
                )
            }
            var rvisit: DataVisit?
            if let visit = item as? Visit {
                rvisit = DataVisit(
                    activityType: visit.activityType?.displayName ?? "Unknown",
                    duration: visit.duration,
                    latitude: visit.center?.coordinate.latitude ?? 0.0,
                    longitude: visit.center?.coordinate.longitude ?? 0.0,
                    radius: visit.radius2sd
                )
            }
            let result = LocoKitData(
                altitude: item.altitude ?? -1,
                classifierResults: ClassifierResults(
                    best: Best(
                        modelAccuracyScore: classifierResults.best.modelAccuracyScore ?? 0.0,
                        name: classifierResults.best.name.displayName,
                        score: classifierResults.best.score
                    )
                ),
                dateRange: DateRange(
                    end:  item.dateRange?.end,
                    start: item.dateRange?.start
                ),
                floorsAscended: item.floorsAscended ?? 0,
                floorsDescended: item.floorsDescended ?? 0,
                keepnessScore: item.keepnessScore,
                dataPath: rpath,
                dataSamples: item.samples.map { sample in
                    let date = sample.date
                    let latitude = sample.location?.coordinate.latitude ?? nil
                    let longitude = sample.location?.coordinate.longitude ?? nil
                    let courseVariance = sample.courseVariance ?? 0
                    let stepHz = sample.stepHz ?? 0.0
                    let activityType:String = sample.activityType?.displayName ?? "Unknown"
                    return DataSample(
                        activityType: activityType,
                        coordinates: Coordinates(lat: latitude, lng: longitude),
                        courseVariance: courseVariance,
                        date: date,
                        stepHz: stepHz
                    )
                },
                dataVisit: rvisit
            );
            
            let jsonEncoder = JSONEncoder()
            do {
                let jsonData = try jsonEncoder.encode(result)
                let jsonString = String(data: jsonData, encoding: .utf8)
                print("JSON String : " + jsonString!)
                self.sendEvent(withName: EventTypes.timeLineStatusEvent.rawValue, body: jsonString)
            }
            catch {
                print("Error Parsing JSON")
            }
        }
    }
    
}
