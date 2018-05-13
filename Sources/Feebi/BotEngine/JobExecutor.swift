//
//  File.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/12/18.
//

import Foundation
import ReactiveSwift
import Result

protocol RecurringJob: Codable {
    
    var id: UUID? { get set }
    var executedAt: Date? { get set }
    var executionInterval: TimeInterval { get }
    
    func execute() -> SignalProducer<RecurringJobExecutionResult, AnyError>

}

protocol RecurringJobExecutor {
    
    associatedtype RecurringJobType: RecurringJob
    
    func execute(job: RecurringJobType) -> SignalProducer<RecurringJobExecutionResult, AnyError>
    
}

enum RecurringJobExecutionResult {
    
    case completed
    case succeded
    
}

enum RecurringJobStoreError: Error {
    
    case jobNotFound(jobId: UUID)
    case internalStoreError(Error)
    
}

protocol RecurringJobStore {
    
    func save(job: RecurringJob) -> SignalProducer<RecurringJob, RecurringJobStoreError>
    
    func removeJob(withId jobId: UUID) -> SignalProducer<(), RecurringJobStoreError>
    
    func fetchJob(withId jobId: UUID) -> SignalProducer<RecurringJob, RecurringJobStoreError>
    
    func fetchJobs() -> SignalProducer<[RecurringJob], RecurringJobStoreError>
}

final class InMemoryRecurringJobStore: RecurringJobStore {
    
    private var jobs: [UUID : RecurringJob] = [:]
    
    func save(job: RecurringJob) -> SignalProducer<RecurringJob, RecurringJobStoreError> {
        if let jobId = job.id {
            jobs[jobId] = job
            return SignalProducer(value: job)
        } else {
            var savedJob = job
            savedJob.id = UUID()
            jobs[savedJob.id!] = savedJob
            return SignalProducer(value: savedJob)
        }
    }
    
    func removeJob(withId jobId: UUID) -> SignalProducer<(), RecurringJobStoreError> {
        if jobs.removeValue(forKey: jobId) == nil {
            return SignalProducer(error: .jobNotFound(jobId: jobId))
        } else {
            return SignalProducer(value: ())
        }
    }
    
    func fetchJob(withId jobId: UUID) -> SignalProducer<RecurringJob, RecurringJobStoreError> {
        if let job = jobs[jobId] {
            return SignalProducer(value: job)
        } else {
            return SignalProducer(error: .jobNotFound(jobId: jobId))
        }
    }
    
    func fetchJobs() -> SignalProducer<[RecurringJob], RecurringJobStoreError> {
        return SignalProducer(value: Array(jobs.values))
    }
    
}

typealias RecurringJobProducer = SignalProducer<RecurringJob, RecurringJobQueueError>

protocol RecurringJobQueue {
    
    func enqueue(job: RecurringJob) -> RecurringJobProducer
    
}

enum RecurringJobQueueError: Swift.Error {
    
    case storeError(RecurringJobStoreError)
    case jobExecutionError(Swift.Error)
    
}

final class RecurringJobOrchestrator: RecurringJobQueue {
    
    struct BootstrapData {
        
        let activeJobsCount: UInt
        let currentExecutionInterval: TimeInterval
        
    }
    
    private let store: RecurringJobStore
    private let queue = DispatchQueue(
        label: "RecurringJobOrchestrator.ScheduledJobsQueue",
        attributes: .concurrent
    )
    
    init(store: RecurringJobStore) {
        self.store = store
    }
    
    func bootstrap() -> SignalProducer<[RecurringJob], RecurringJobQueueError> {
        return store.fetchJobs()
            .mapError(RecurringJobQueueError.storeError)
            .on(value: { jobs in
                for job in jobs {
                    guard let jobId = job.id else {
                        continue
                    }
                    self.enqueueJob(jobId: jobId, executionInterval: job.executionInterval)
                }
            })
    }
    
    func enqueue(job: RecurringJob) -> SignalProducer<RecurringJob, RecurringJobQueueError> {
        return store.save(job: job)
            .mapError(RecurringJobQueueError.storeError)
            .on(value: { savedJob in
                guard let jobId = savedJob.id else {
                    return
                }
                self.enqueueJob(jobId: jobId, executionInterval: job.executionInterval)
            })
    }
    
}

fileprivate extension RecurringJobOrchestrator {
    
    func enqueueJob(jobId: UUID, executionInterval: TimeInterval) {
        queue.asyncAfter(deadline: .now() + executionInterval) {
            self.store.fetchJob(withId: jobId)
                .mapError(RecurringJobQueueError.storeError)
                .flatMap(.concat, self.executeJob)
                .flatMap(.concat, self.handleJobExecutionResult)
                .startWithFailed(self.handleJobError(forJob: jobId))
        }
    }
    
    func handleJobError(forJob jobId: UUID) -> (Error) -> Void {
        // TODO Do something better about job failures
        return { error in print("WARN - Job with id '\(jobId)' has failed: \(error)") }
    }
    
    func executeJob(_ job: RecurringJob) -> SignalProducer<(RecurringJobExecutionResult, RecurringJob), RecurringJobQueueError> {
        return job.execute()
            .mapError(RecurringJobQueueError.jobExecutionError)
            .map { ($0, job) }
    }
    
    func handleJobExecutionResult(_ boundResult: (RecurringJobExecutionResult, RecurringJob))
        -> SignalProducer<RecurringJob, RecurringJobQueueError> {
        var job = boundResult.1
        guard let jobId = boundResult.1.id else {
            fatalError("Cannot handle job execution result for a non-persisted job")
        }
        
        switch boundResult.0 {
        case .completed:
            return store.removeJob(withId: jobId)
                .mapError(RecurringJobQueueError.storeError)
                .then(SignalProducer(value: job))
            
        case .succeded:
            job.executedAt = Date()
            return store.save(job: job)
                .mapError(RecurringJobQueueError.storeError)
                .on(started: {
                    self.enqueueJob(jobId: jobId, executionInterval: job.executionInterval)
                })
        }
    }
    
}
