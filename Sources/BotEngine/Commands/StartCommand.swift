//
//  RunCommand.swift
//  BotEngine
//
//  Created by Guido Marucci Blas on 7/8/18.
//

import Foundation
import Result
import Commandant
import BotEngineKit
import GoogleAPI
import ReactiveSwift
import GoogleOAuth
import Curry

enum CommandLineError: Error, CustomStringConvertible {
    
    case cannotBootstrapDependencies
    case cannotStartHTTPServer
    case cannotObtainGoogleAPIAccessToken
    
    var description: String {
        switch self {
        case .cannotBootstrapDependencies:
            return "Unable to bootstrap dependencies"
        case .cannotStartHTTPServer:
            return "Unable to start HTTP server"
        case .cannotObtainGoogleAPIAccessToken:
            return "Unable to obtain Google API OAuth access token"
        }
    }
    
    var code: Int32 {
        return Int32((self as NSError).code)
    }
    
}

struct StartCommand: CommandProtocol {
    
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
        
        static func evaluate(_ mode: CommandMode) -> Result<GCloudOptions, CommandantError<CommandLineError>> {
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
        
        static func evaluate(_ mode: CommandMode) -> Result<LoggerOptions, CommandantError<CommandLineError>> {
            return curry(LoggerOptions.init)
                <*> mode <| verbose
                <*> mode <| googleApiPrintCurl
                <*> mode <| googleApiPrintRequest
                <*> mode <| firestorePrintSerializationLog
        }
        
        
    }
    
    
    struct Options: OptionsProtocol {
    
        private static let hostname = Option<String>(
            key: "hostnanme",
            defaultValue: "0.0.0.0",
            usage: "sets the bot engine's HTTP server listening hostname"
        )
        private static let port = Option<Int>(
            key: "port",
            defaultValue: 8080,
            usage: "sets the bot engine's HTTP server listening port"
        )
        private static let outputChannel = Option<String>(
            key: "output-channel",
            defaultValue: "general",
            usage: "sets the bot engine's logs output channel"
        )
        
        let hostname: String
        let port: Int
        let outputChannel: String
        let gcloudOptions: GCloudOptions
        let loggerOptions: LoggerOptions
        
        static func evaluate(_ mode: CommandMode) -> Result<Options, CommandantError<CommandLineError>> {
            return curry(Options.init)
                <*> mode <| hostname
                <*> mode <| port
                <*> mode <| outputChannel
                <*> GCloudOptions.evaluate(mode)
                <*> LoggerOptions.evaluate(mode)
        }

        
    }
    
    
    let verb = "start"
    
    let function = "Starts the bot engine server"
    
    func run(_ options: Options) -> Result<(), CommandLineError> {
        
        func isEnabled(_ keyPath: KeyPath<LoggerOptions, Bool>) -> Bool {
            return options.loggerOptions.verbose || options.loggerOptions[keyPath: keyPath]
        }

        if options.loggerOptions.verbose {
            print("INFO - Verbose mode enabled")
        }
        
        GoogleAPI.shared.printDebugCurlCommand = isEnabled(\.googleApiPrintCurl)
        GoogleAPI.shared.printRequest = isEnabled(\.googleApiPrintRequest)
        FirestoreDocument.printSerializationDebugLog = isEnabled(\.firestorePrintSerializationLog)

        let dependenciesProducer = startHTTPServer(with: options).flatMap(.concat, fetchGoogleAPIToken(with: options))
        guard let result = dependenciesProducer.first() else {
            return .failure(.cannotBootstrapDependencies)
        }
        
        switch result {
        case .success(let context):
            startBotEngine(with: context)
        case .failure(let error):
            return .failure(error)
        }
    }

}

fileprivate extension StartCommand {
    
    struct Context {
        
        let httpServer: BotEngine.HTTPServer
        let googleToken: GoogleAPI.Token
        let options: Options
        
    }
    
    func startHTTPServer(with options: Options) -> SignalProducer<BotEngine.HTTPServer, CommandLineError> {
        return BotEngine.HTTPServer
            .build(hostname: options.hostname, port: options.port)
            .mapError { _ in .cannotStartHTTPServer }
            .on(starting: { print("INFO - Starting HTTP server at port '\(options.port)'") })
    }
    
    func fetchGoogleAPIToken(with options: Options) -> (BotEngine.HTTPServer) -> SignalProducer<Context, CommandLineError> {
        return { httpServer in
            let env = ProcessInfo.processInfo.environment
            let tokenProducer: SignalProducer<GoogleAPI.Token, CommandLineError>
            if let gcloudEncodedCredentials = env["GCLOUD_ENCODED_CREDENTIALS"].flatMap({ Data(base64Encoded: $0) }) {
                tokenProducer = self.fetchGoogleAPIToken(
                    encodedCredentials: gcloudEncodedCredentials,
                    delegatedAccount: options.delegatedAccount
                )
            } else if let gcloudCredentialsFile = options.credentialsFile  {
                tokenProducer = self.fetchGoogleAPIToken(
                    credentialsFile: gcloudCredentialsFile,
                    delegatedAccount: options.delegatedAccount
                )
            } else {
                tokenProducer = SignalProducer<GoogleAPI.Token, AnyError> { try GoogleAuth().login(with: httpServer) }
                    .mapError { _ in .cannotObtainGoogleAPIAccessToken }
            }
            return tokenProducer.map { Context(httpServer: httpServer, googleToken: $0, options: options) }
                .on(starting: {
                    if let delegatedAccount = options.delegatedAccount {
                        print("INFO - Delegating GCloud service account to '\(delegatedAccount)'")
                    }
                })
        }
    }
    
    func fetchGoogleAPIToken(credentialsFile: URL, delegatedAccount: String?) -> SignalProducer<GoogleAPI.Token, CommandLineError> {
        return GoogleAuth().login(
            serviceAccountCredentials: credentialsFile,
            delegatedAccount: delegatedAccount
        )
        .mapError { _ in .cannotObtainGoogleAPIAccessToken }
        .on(starting: { print("INFO - Using google service account credentials file: '\(credentialsFile)'") })
    }
    
    func fetchGoogleAPIToken(encodedCredentials: Data, delegatedAccount: String?) -> SignalProducer<GoogleAPI.Token, CommandLineError> {
        return GoogleAuth().login(
            serviceAccountCredentials: encodedCredentials,
            delegatedAccount: delegatedAccount
        )
        .mapError { _ in .cannotObtainGoogleAPIAccessToken }
        .on(starting: { print("INFO - Using google service account encoded credentials") })
    }
    
    func startBotEngine(with context: Context) -> Never {
        print("INFO - Running bot engine ...")
        let engine = BotEngine.slackBotEngine(
            server: context.httpServer,
            repository: FirebaseObjectRepository(
                token: context.googleToken,
                projectId: "feedi-dev",
                databaseId: "(default)"
            ),
            outputChannel: context.options.outputChannel,
            context: [
                ContextKey.googleToken.rawValue : context.googleToken
            ]
        )
        
        // Register behaviors
        engine.registerBehavior(CreateSurveyBehavior())
        engine.registerBehavior(RandomMathQuestionBehavior())
        
        // Enqueue actions
        let argentinaTimezone = "America/Argentina/Buenos_Aires"
        engine.enqueueAction(
            interval: .everyDay(at: .at("14:00", in: argentinaTimezone)!),
            action: SyncArgentinaMailingLists()
        )
        engine.enqueueAction(
            interval: .everyDay(at: .at("14:05", in: argentinaTimezone)!),
            action: SyncMailChimpMailingList()
        )
        
        // Bind actions
        engine.bindAction(SyncArgentinaMailingLists(), to: "sync argentinean mailing lists")
        engine.bindAction(SyncMailChimpMailingList(), to: "sync mailchimp mailing list")
        
        engine.start()
        
        while true {
            fflush(stdout)
            usleep(10)
        }
    }
}

fileprivate extension StartCommand.Options {
    
    var credentialsFile: URL? {
        return self.gcloudOptions.credentialsFile.map(URL.init(fileURLWithPath:))
    }
    
    var delegatedAccount: String? {
        return self.gcloudOptions.delegatedAccount
    }
    
}
