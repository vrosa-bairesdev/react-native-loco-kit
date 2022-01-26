// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let locoKitData = try? newJSONDecoder().decode(LocoKitData.self, from: jsonData)

import Foundation

// MARK: - LocoKitData
class LocoKitData: Codable {
    let altitude: Double
    let classifierResults: ClassifierResults
    let dateRange: DateRange
    let floorsAscended, floorsDescended, keepnessScore: Int
    let dataPath: DataPath?
    let dataSamples: [DataSample]
    let dataVisit: DataVisit?

    init(
        altitude: Double,
        classifierResults: ClassifierResults,
        dateRange: DateRange,
        floorsAscended: Int,
        floorsDescended: Int,
        keepnessScore: Int,
        dataPath: DataPath?,
        dataSamples: [DataSample],
        dataVisit: DataVisit?
    ) {
        self.altitude = altitude
        self.classifierResults = classifierResults
        self.dateRange = dateRange
        self.floorsAscended = floorsAscended
        self.floorsDescended = floorsDescended
        self.keepnessScore = keepnessScore
        self.dataPath = dataPath
        self.dataSamples = dataSamples
        self.dataVisit = dataVisit
    }
}

// MARK: - ClassifierResults
class ClassifierResults: Codable {
    let best: Best

    init(best: Best) {
        self.best = best
    }
}

// MARK: - Best
class Best: Codable {
    let modelAccuracyScore: Double
    let name: String
    let score: Double

    init(modelAccuracyScore: Double, name: String, score: Double) {
        self.modelAccuracyScore = modelAccuracyScore
        self.name = name
        self.score = score
    }
}

// MARK: - DataPath
class DataPath: Codable {
    let distance, speed, kph: Double
    let activityType: String

    init(distance: Double, speed: Double, kph: Double, activityType: String) {
        self.distance = distance
        self.speed = speed
        self.kph = kph
        self.activityType = activityType
    }
}

// MARK: - DataSample
class DataSample: Codable {
    let activityType: String
    let coordinates: Coordinates
    let courseVariance: Double
    let date: Date
    let stepHz: Double

    init(activityType: String, coordinates: Coordinates, courseVariance: Double, date: Date, stepHz: Double) {
        self.activityType = activityType
        self.coordinates = coordinates
        self.courseVariance = courseVariance
        self.date = date
        self.stepHz = stepHz
    }
}

// MARK: - Coordinates
class Coordinates: Codable {
    let lat:Double?
    let lng: Double?

    init(lat: Double?, lng: Double?) {
        self.lat = lat
        self.lng = lng
    }
}

// MARK: - DataVisit
class DataVisit: Codable {
    let activityType: String
    let duration, latitude, longitude, radius: Double

    init(activityType: String, duration: Double, latitude: Double, longitude: Double, radius: Double) {
        self.activityType = activityType
        self.duration = duration
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }
}

// MARK: - DateRange
class DateRange: Codable {
    let end, start: Date?

    init(end: Date?, start: Date?) {
        self.end = end
        self.start = start
    }
}
