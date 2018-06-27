//
//  Google.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/4/18.
//

import Foundation
import GoogleOAuth
import GoogleAPI
import ReactiveSwift
import Result

public final class GoogleAuth {
    
    let credentialsFilename = "feebi.json"
    let scopes = [
        "https://www.googleapis.com/auth/spreadsheets.readonly",
        "https://www.googleapis.com/auth/forms",
        "https://www.googleapis.com/auth/drive.metadata.readonly",
        "https://www.googleapis.com/auth/datastore",
        "https://www.googleapis.com/auth/admin.directory.group",
        "https://www.googleapis.com/auth/admin.directory.user.readonly"
    ]

    private let tokenFilename = ".feebi-token"
    
    public init() { }
    
    public func login(serviceAccountCredentials credentials: URL, delegatedAccount: String? = .none) -> SignalProducer<GoogleAPI.Token, AnyError> {
        guard let tokenProvider = ServiceAccountTokenProvider(credentialsURL: credentials, scopes: scopes) else {
            fatalError("ERROR - Unable to create token provider")
        }
        return SignalProducer { observer, _ in
            do {
                try tokenProvider.withToken(delegatedAccount: delegatedAccount) { maybeToken, maybeError in
                    if let error = maybeError {
                        observer.send(error: AnyError(error))
                    } else if let token = maybeToken?.asGoogleToken {
                        observer.send(value: token)
                        observer.sendCompleted()
                    } else {
                        fatalError("ERROR - Unable to create token")
                    }
                }
            } catch let error {
                observer.send(error: AnyError(error))
            }
        }
    }
    
    public func login(with server: BotEngine.HTTPServer) throws -> GoogleAPI.Token {
        guard let tokenProvider = BrowserTokenProvider(
            credentials: credentialsFilename,
            token: tokenFilename,
            oauthCallbackBaseURL: server.host) else {
            fatalError("ERROR - Unable to create token provider")
        }

        if tokenProvider.token == nil {
            let sem = DispatchSemaphore(value: 0)
            server.registerTemporaryHandler(forPath: tokenProvider.callbackPath) { request in
                defer {
                    sem.signal()
                }
                guard let urlComponents = request.urlComponents else {
                    print("WARN - URL components could not be created for URL '\(request.url.absoluteString)'")
                    return .init(value: .badRequest)
                }
                do {
                    try tokenProvider.exchange(code: Code(urlComponents: urlComponents))
                    return .init(value: .success("Success! Token received.\n"))
                } catch let error {
                    return .init(error: AnyError(error))
                }
            }
            try tokenProvider.signIn(scopes: scopes)
            _ = sem.wait(timeout: DispatchTime.distantFuture)
            try tokenProvider.saveToken(tokenFilename)
        }

        return tokenProvider.token!.asGoogleToken!
    }
    
}

fileprivate extension Token {

    var asGoogleToken: GoogleAPI.Token? {
        guard let tokenType = self.TokenType, let tokenValue = self.AccessToken else {
            return nil
        }
        return GoogleAPI.Token(type: tokenType, value: tokenValue)
    }

}
