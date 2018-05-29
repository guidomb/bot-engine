//
//  ScheduledJob.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/17/18.
//

import Foundation
import Result
import ReactiveSwift

enum BehaviorJobOutput {
    
    case completed(outputs: [ChanneledBehaviorOutput])
    case success(outputs: [ChanneledBehaviorOutput])
    
}

protocol BehaviorJobExecutor {
    
    associatedtype JobMessageType: Codable
    
    func executeJob(with message: JobMessageType) -> SignalProducer<BehaviorJobOutput, AnyError>
    
}

protocol BehaviorJobScheduler {
    
    func schedule<BehaviorType: BehaviorProtocol>(
        job: SchedulableJob<BehaviorType.JobMessageType>,
        for behavior: BehaviorType
    )
    
}

struct NoJobMessage: Codable {
    
    private let neededToMakeItConformToCodable: Int
    
}

struct DayTime: Codable {
    
    static func at(_ dayTimeHours: String, in timeZone: String? = .none) -> DayTime? {
        let components = dayTimeHours.split(separator: ":")
        guard components.count == 2, let hours = Int(components[0]), let minutes = Int(components[1]) else {
            return .none
        }
        return at(hours: hours, minutes: minutes, timeZone: timeZone)
    }
    
    static func at(hours: Int, minutes: Int, timeZone: String? = .none) -> DayTime? {
        if timeZone == nil {
            return DayTime(hours: hours, minutes: minutes)
        } else {
            guard let timeZone = timeZone.flatMap({ TimeZone(identifier: $0) }) else {
                return .none
            }
            return DayTime(hours: hours, minutes: minutes, timeZone: timeZone)
        }
    }
    
    let hours: Int
    let minutes: Int
    let timeZone: TimeZone
    
    init?(hours: Int, minutes: Int, timeZone: TimeZone = TimeZone.current) {
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
    
    func toDate(in day: Date = Date()) -> Date? {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar.date(bySettingHour: hours, minute: minutes, second: 0, of: day)
    }
    
    func intervalSinceNow() -> TimeInterval? {
        guard let interval = toDate()?.timeIntervalSinceNow else {
            return .none
        }
        
        // If interval is negative it means that `self`
        // (today's day time) has already passed.
        // In which case we need to calculate the interval
        // for the same day time but for the following day
        return interval > 0 ? interval : ((24 * 60 * 60) + interval)
    }
    
}

struct SchedulableJob<JobMessageType: Codable>: Codable {
    
    enum Interval: AutoCodable {
        
        case every(seconds: TimeInterval)
        case everyDay(at: DayTime)
        
        func intervalSinceNow() -> TimeInterval? {
            switch self {
            case .every(let seconds):
                return seconds
            case .everyDay(let dayTime):
                return dayTime.intervalSinceNow()
            }
        }
        
    }
    
    let interval: Interval
    let message: JobMessageType
    
    func asLongLivedJob() -> ScheduledJob<JobMessageType> {
        return ScheduledJob<JobMessageType>.longLived(self)
    }
    
    func asCancelableJob() -> ScheduledJob<JobMessageType> {
        return ScheduledJob<JobMessageType>.cancelableJob(self)
    }
    
}

struct ScheduledJob<JobMessageType: Codable>: Persistable, Codable {
    
    static func cancelableJob<JobMessageType: Codable>(_ job: SchedulableJob<JobMessageType>) -> ScheduledJob<JobMessageType> {
        return .init(job: job, isCancelable: true)
    }
    
    static func longLived<JobMessageType: Codable>(_ job: SchedulableJob<JobMessageType>) -> ScheduledJob<JobMessageType> {
        return .init(job: job, isCancelable: false)
    }
    
    var id: Identifier<ScheduledJob>?
    let isCancelable: Bool
    let job: SchedulableJob<JobMessageType>
    
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

struct NoBehaviorJobExecutor: BehaviorJobExecutor {
    
    private init() {}
    
    func executeJob(with message: NoJobMessage) -> SignalProducer<BehaviorJobOutput, AnyError> {
        return .empty
    }
    
}

struct BehaviorSchedulableJobs<BehaviorJobExecutorType: BehaviorJobExecutor> {
    
    typealias JobMessageType = BehaviorJobExecutorType.JobMessageType
    
    let jobs: [SchedulableJob<JobMessageType>]
    let executor: AnyBehaviorJobExecutor<JobMessageType>
    
    init(jobs: [SchedulableJob<JobMessageType>] = [], executor: BehaviorJobExecutorType) {
        self.jobs = jobs
        self.executor = AnyBehaviorJobExecutor(executor)
    }
}
