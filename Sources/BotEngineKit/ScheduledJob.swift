//
//  ScheduledJob.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/17/18.
//

import Foundation
import Result
import ReactiveSwift

public enum BehaviorJobOutput {
    
    case completed(outputs: [ChanneledBehaviorOutput])
    case success(outputs: [ChanneledBehaviorOutput])
    
}

public protocol BehaviorJobExecutor {
    
    associatedtype JobMessageType: Codable
    
    func executeJob(with message: JobMessageType) -> SignalProducer<BehaviorJobOutput, AnyError>
    
}

public protocol BehaviorJobScheduler {
    
    func schedule<BehaviorType: BehaviorProtocol>(
        job: SchedulableJob<BehaviorType.JobMessageType>,
        for behavior: BehaviorType
    )
    
}

public struct NoJobMessage: Codable {
    
    private let neededToMakeItConformToCodable: Int
    
}

public struct DayTime: Codable {
    
    public static func at(_ dayTimeHours: String, in timeZone: String? = .none) -> DayTime? {
        let components = dayTimeHours.split(separator: ":")
        guard components.count == 2, let hours = Int(components[0]), let minutes = Int(components[1]) else {
            return .none
        }
        return at(hours: hours, minutes: minutes, timeZone: timeZone)
    }
    
    public static func at(hours: Int, minutes: Int, timeZone: String? = .none) -> DayTime? {
        if timeZone == nil {
            return DayTime(hours: hours, minutes: minutes)
        } else {
            guard let timeZone = timeZone.flatMap({ TimeZone(identifier: $0) }) else {
                return .none
            }
            return DayTime(hours: hours, minutes: minutes, timeZone: timeZone)
        }
    }
    
    public let hours: Int
    public let minutes: Int
    public let timeZone: TimeZone
    
    public init?(hours: Int, minutes: Int, timeZone: TimeZone = TimeZone.current) {
        guard hours >= 0 && hours < 24 else {
            return nil
        }
        guard minutes >= 0 && minutes < 60 else {
            return nil
        }
        self.hours = hours
        self.minutes = minutes
        self.timeZone = timeZone
    }
    
    public func toDate(in dayDate: Date = Date()) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        // Ideally the following calendar method should do the work. But this method
        // when using Swift's open source Foundation dependends on a method that
        // is not implemented yet.
        // https://github.com/apple/swift-corelibs-foundation/blob/da6a830f7e461062c8ba82961f644c4a197890be/Foundation/NSCalendar.swift#L1109
        // return calendar.date(bySettingHour: hours, minute: minutes, second: 0, of: day)

        let day = String(format: "%02d", calendar.component(.day, from: dayDate))
        let month = String(format: "%02d", calendar.component(.month, from: dayDate))
        let year = calendar.component(.year, from: dayDate)
        
        var time = String(format: "%02d", hours)
        time += ":" + String(format: "%02d", minutes) + ":00"
        
        let secondsFromGMT = timeZone.secondsFromGMT()
        let timeZoneHours = String(format: "%02d", abs(secondsFromGMT / 60 / 60))
        let timeZoneMinutes = String(format: "%02d", abs((secondsFromGMT % (60 * 60)) / 60))
        var timeZoneComponent = secondsFromGMT > 0 ? "+" : "-"
        timeZoneComponent += "\(timeZoneHours):\(timeZoneMinutes)"
        let dayString = "\(year)-\(month)-\(day)T\(time)\(timeZoneComponent)"
        return formatter.date(from: dayString)
    }
    
    public func intervalSinceNow() -> TimeInterval? {
        return intervalSince(dayDate: Date())
    }
    
    public func intervalSince(dayDate: Date) -> TimeInterval? {
        print("DEBUG - intervalSince(dayDate: '\(dayDate)' ---> toDate = \(toDate(in: dayDate)!)")
        guard let interval = toDate(in: dayDate)?.timeIntervalSince(dayDate) else {
            return .none
        }
        
        // If interval is negative it means that `self`
        // is earlier that `dayDate` day time. In which case we need
        // to return the absolute number.
        //
        // Otherwise, it means that `self` is later than `dayDate`'s day time.
        // Which means that we need to calculate the time difference
        // between `self` and `dayDate`'s day time for the following date
        //
        // Example
        //
        //  let a = DayTime("10:30")
        //  let b = DayTime("10:40")
        //  a.intervalSince(dayTime: b) -> 600 = 10 minutes
        //  b.intervalSince(dayTime: a) -> 85800 = 23 hours and 50 minutes = 24 hours - 10 minutes
        return interval <= 0 ? abs(interval) : ((24 * 60 * 60) - interval)
    }
    
}

extension DayTime: AutoEquatable {
    
}

extension DayTime: Comparable {
    
    public static func < (lhs: DayTime, rhs: DayTime) -> Bool {
        return (lhs.hours < rhs.hours) || (lhs.hours == rhs.hours && lhs.minutes < rhs.minutes)
    }
    
    
}

extension DayTime: CustomStringConvertible {
    
    public var description: String {
        return "\(String(format: "%02d:%02d", hours, minutes)) \(timeZone) time zone"
    }
    
}

public enum SchedulerInterval: AutoCodable, CustomStringConvertible {
    
    case every(seconds: TimeInterval)
    case everyDay(at: DayTime)
    
    public var description: String {
        switch self {
        case .every(let seconds):
            return "every \(seconds) seconds"
        case .everyDay(let dayTime):
            return "every day at \(dayTime)"
        }
    }
    
    public func intervalSinceNow() -> TimeInterval? {
        switch self {
        case .every(let seconds):
            return seconds
        case .everyDay(let dayTime):
            return dayTime.intervalSinceNow()
        }
    }
    
}

public struct SchedulableJob<JobMessageType: Codable>: Codable {
    
    public let interval: SchedulerInterval
    public let message: JobMessageType
    
    func asLongLivedJob() -> ScheduledJob<JobMessageType> {
        return ScheduledJob<JobMessageType>.longLived(self)
    }
    
    func asCancelableJob() -> ScheduledJob<JobMessageType> {
        return ScheduledJob<JobMessageType>.cancelableJob(self)
    }
    
}

public struct NoBehaviorJobExecutor: BehaviorJobExecutor {
    
    private init() {}
    
    public func executeJob(with message: NoJobMessage) -> SignalProducer<BehaviorJobOutput, AnyError> {
        return .empty
    }
    
}

public struct BehaviorSchedulableJobs<BehaviorJobExecutorType: BehaviorJobExecutor> {
    
    typealias JobMessageType = BehaviorJobExecutorType.JobMessageType
    
    let jobs: [SchedulableJob<JobMessageType>]
    let executor: AnyBehaviorJobExecutor<JobMessageType>
    
    init(jobs: [SchedulableJob<JobMessageType>] = [], executor: BehaviorJobExecutorType) {
        self.jobs = jobs
        self.executor = AnyBehaviorJobExecutor(executor)
    }
}

public struct ScheduledJob<JobMessageType: Codable>: Persistable, Codable {
    
    public static func cancelableJob<JobMessageType: Codable>(_ job: SchedulableJob<JobMessageType>) -> ScheduledJob<JobMessageType> {
        return .init(job: job, isCancelable: true)
    }
    
    public static func longLived<JobMessageType: Codable>(_ job: SchedulableJob<JobMessageType>) -> ScheduledJob<JobMessageType> {
        return .init(job: job, isCancelable: false)
    }
    
    public var id: Identifier<ScheduledJob>?
    public let isCancelable: Bool
    public let job: SchedulableJob<JobMessageType>
    
    private init(id: Identifier<ScheduledJob>? = .none, job: SchedulableJob<JobMessageType>,  isCancelable: Bool) {
        self.id = id
        self.isCancelable = isCancelable
        self.job = job
    }
    
}

struct AnyBehaviorJobExecutor<JobMessageType: Codable>: BehaviorJobExecutor {
    
    private let _executeJob: (JobMessageType) -> SignalProducer<BehaviorJobOutput, AnyError>
    
    init<ScheduledJobExecutorType: BehaviorJobExecutor>(_ executor: ScheduledJobExecutorType)
        where JobMessageType == ScheduledJobExecutorType.JobMessageType {
        self._executeJob = executor.executeJob
    }
    
    func executeJob(with message: JobMessageType) -> SignalProducer<BehaviorJobOutput, AnyError> {
        return _executeJob(message)
    }
    
}
