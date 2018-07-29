//
//  Options.swift
//  BotEngineCLI
//
//  Created by Guido Marucci Blas on 7/28/18.
//

import Foundation
import Commandant
import Curry

extension BotEngineCLI {
    
    struct GCloudOptions: OptionsProtocol {
        
        private static let prefix = "gcloud"
        private static let credentialsFile = Option<String?>(
            key: "\(prefix)-credentials-file",
            defaultValue: .none,
            usage: "a file path to the location of service account credentials JSON file."
        )
        private static let delegatedAccount = Option<String?>(
            key: "\(prefix)-delegated-account",
            defaultValue: .none,
            usage: "a valid gcloud email address to delegate access to when authenticating via a service account"
        )
        
        let credentialsFile: String?
        let delegatedAccount: String?
        
        static func evaluate(_ mode: CommandMode) -> Result<GCloudOptions, CLIError> {
            return curry(GCloudOptions.init)
                <*> mode <| credentialsFile
                <*> mode <| delegatedAccount
        }
        
    }
    
    struct LoggerOptions: OptionsProtocol {
        
        private static let verbose = Option<Bool>(
            key: "verbose",
            defaultValue: false,
            usage: "print all debug logs"
        )
        private static let googleApiPrintCurl = Option<Bool>(
            key: "google-api-print-curl",
            defaultValue: false,
            usage: "print curl debug command when executing Google API request"
        )
        private static let googleApiPrintRequest = Option<Bool>(
            key: "google-api-print-request",
            defaultValue: false,
            usage: "print Google API requests"
        )
        private static let firestorePrintSerializationLog = Option<Bool>(
            key: "firestore-print-serialization",
            defaultValue: false,
            usage: "print debug serialization logs when serializing/deserializing Firestore objects"
        )
        
        let verbose: Bool
        let googleApiPrintCurl: Bool
        let googleApiPrintRequest: Bool
        let firestorePrintSerializationLog: Bool
        
        static func evaluate(_ mode: CommandMode) -> Result<LoggerOptions, CLIError> {
            return curry(LoggerOptions.init)
                <*> mode <| verbose
                <*> mode <| googleApiPrintCurl
                <*> mode <| googleApiPrintRequest
                <*> mode <| firestorePrintSerializationLog
        }
        
        
    }
    
}
