//
//  RunCommand.swift
//  BotEngine
//
//  Created by Guido Marucci Blas on 7/8/18.
//

@_exported import BotEngineKit
import Commandant
import Curry
import Foundation

extension BotEngineCLI {
    
    struct StartCommand: CommandProtocol {
        
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
            private static let admins = Option<[String]>(
                key: "admins",
                defaultValue: [],
                usage: "a comma-separated list of users id who would act as admins"
            )
            
            let hostname: String
            let port: Int
            let outputChannel: String
            let admins: [String]
            let gcloudOptions: GCloudOptions
            let loggerOptions: LoggerOptions
            
            static func evaluate(_ mode: CommandMode) -> Result<Options, CLIError> {
                return curry(Options.init)
                    <*> mode <| hostname
                    <*> mode <| port
                    <*> mode <| outputChannel
                    <*> mode <| admins
                    <*> GCloudOptions.evaluate(mode)
                    <*> LoggerOptions.evaluate(mode)
            }
            
            
        }
        
        let verb = "start"
        let function = "Starts the bot engine server"
        
        private let configuration: Configuration
        private let botBuilder: BotBuilder
        
        public init(configuration: Configuration, botBuilder: @escaping BotBuilder) {
            self.configuration = configuration
            self.botBuilder = botBuilder
        }
        
        func run(_ options: Options) -> Result<(), BotEngineCLI.CommandLineError> {
            if options.loggerOptions.verbose {
                print("INFO - Verbose mode enabled")
            }
            
            let dependenciesProducer = startHTTPServer(with: options).map(contextBuilder(with: options))
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
    
}

fileprivate extension BotEngineCLI.StartCommand {
    
    struct Context {
        
        let httpServer: BotEngine.HTTPServer
        let googleAPIResourceExecutor: GoogleAPIResourceExecutor
        let options: Options
        
    }
    
    func startHTTPServer(with options: Options) -> SignalProducer<BotEngine.HTTPServer, BotEngineCLI.CommandLineError> {
        return BotEngine.HTTPServer
            .build(hostname: options.hostname, port: options.port)
            .mapError { _ in .cannotStartHTTPServer }
            .on(starting: { print("INFO - Starting HTTP server at port '\(options.port)'") })
    }
    
    func contextBuilder(with options: Options) -> (BotEngine.HTTPServer) -> Context {
        
        func isEnabled(_ keyPath: KeyPath<BotEngineCLI.LoggerOptions, Bool>) -> Bool {
            return options.loggerOptions.verbose || options.loggerOptions[keyPath: keyPath]
        }
        
        return { httpServer in
            let googleApi = self.configuration.createGoogleApi(options: options, server: httpServer)
            googleApi.printDebugCurlCommand = isEnabled(\.googleApiPrintCurl)
            googleApi.printRequest = isEnabled(\.googleApiPrintRequest)
            return Context(httpServer: httpServer, googleAPIResourceExecutor: googleApi, options: options)
        }
    }
    
    func startBotEngine(with context: Context) -> Never {
        print("INFO - Running bot engine ...")
        let repository = configuration.repositoryBuilder(context.googleAPIResourceExecutor, configuration.googleProjectId)
        let engine = BotEngine.slackBotEngine(
            server: context.httpServer,
            repository: repository,
            googleAPIResourceExecutor: context.googleAPIResourceExecutor,
            googleProjectId: configuration.googleProjectId,
            outputChannel: context.options.outputChannel
        )
        engine.admins = context.options.admins.map(BotEngine.UserId.init(value:))
        
        // Register behaviors
        engine.registerBehavior(CreateSurveyBehavior())
        engine.registerBehavior(RandomMathQuestionBehavior())
        engine.registerBehavior(AddIntentBehavior())
        
        botBuilder(engine)
        if !configuration.beforeStart(engine.services) {
            print("INFO - Terminating because before start hook returned false.")
            exit(0)
        }
        engine.start()
        
        while true {
            fflush(stdout)
            usleep(10)
        }
    }
}

fileprivate extension BotEngineCLI.StartCommand.Options {
    
    var credentialsFile: URL? {
        return self.gcloudOptions.credentialsFile.map(URL.init(fileURLWithPath:))
    }
    
    var delegatedAccount: String? {
        return self.gcloudOptions.delegatedAccount
    }
    
}

fileprivate extension BotEngineCLI.Configuration {
    
    func createGoogleApi(options: BotEngineCLI.StartCommand.Options, server: BotEngine.HTTPServer) -> GoogleAPI {
        let authenticationMethod: GoogleAPI.TokenProvider.AuthenticationMethod
        if let gcloudEncodedCredentials = environment["GCLOUD_ENCODED_CREDENTIALS"].flatMap({ Data(base64Encoded: $0) }) {
            authenticationMethod = .serviceAccount(
                credentials: .data(gcloudEncodedCredentials),
                delegatedAccount: options.delegatedAccount
            )
        } else if let gcloudCredentialsFile = options.credentialsFile  {
            authenticationMethod = .serviceAccount(
                credentials: .file(gcloudCredentialsFile),
                delegatedAccount: options.delegatedAccount
            )
        } else {
            authenticationMethod = .oauth(server: server, credentialsFilename: googleAuth.credentialsFilename)
        }
        
        let tokenProvider = GoogleAPI.TokenProvider(scopes: googleAuth.scopes, authenticationMethod: authenticationMethod)
        return GoogleAPI(tokenProvider: tokenProvider)
    }
    
}
