//
//  Auth.swift
//  BotEngine
//
//  Created by Guido Marucci Blas on 7/28/18.
//

import Foundation
import BotEngineKit
import GoogleAPI
import ReactiveSwift
import Result

struct GoogleAuth {
    
    var executor: GoogleAPIResourceExecutor {
        return googleApi
    }
    
    private let googleApi: GoogleAPI
    private let tokenProvider: GoogleAPI.TokenProvider
    private let credentialsFilename = "feebi.json"
    private let scopes = [
        "https://www.googleapis.com/auth/spreadsheets.readonly",
        "https://www.googleapis.com/auth/forms",
        "https://www.googleapis.com/auth/drive.metadata.readonly",
        "https://www.googleapis.com/auth/datastore",
        "https://www.googleapis.com/auth/admin.directory.group",
        "https://www.googleapis.com/auth/admin.directory.user.readonly"
    ]
    
    init(options: StartCommand.Options, server: BotEngine.HTTPServer) {
        
        func isEnabled(_ keyPath: KeyPath<StartCommand.LoggerOptions, Bool>) -> Bool {
            return options.loggerOptions.verbose || options.loggerOptions[keyPath: keyPath]
        }
        
        let env = ProcessInfo.processInfo.environment
        let authenticationMethod: GoogleAPI.TokenProvider.AuthenticationMethod
        if let gcloudEncodedCredentials = env["GCLOUD_ENCODED_CREDENTIALS"].flatMap({ Data(base64Encoded: $0) }) {
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
            authenticationMethod = .oauth(server: server, credentialsFilename: credentialsFilename)
        }
        self.tokenProvider = GoogleAPI.TokenProvider(scopes: scopes, authenticationMethod: authenticationMethod)
        self.googleApi = GoogleAPI(tokenProvider: tokenProvider)
        
        googleApi.printDebugCurlCommand = isEnabled(\.googleApiPrintCurl)
        googleApi.printRequest = isEnabled(\.googleApiPrintRequest)
        FirestoreDocument.printSerializationDebugLog = isEnabled(\.firestorePrintSerializationLog)

    }
    
    func login() -> SignalProducer<GoogleAPI.Token, AnyError> {
        return tokenProvider.fetchToken()
    }
    
}
