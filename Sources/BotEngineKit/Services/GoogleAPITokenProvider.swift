//
//  GoogleAPITokenProvider.swift
//  BotEngine
//
//  Created by Guido Marucci Blas on 7/28/18.
//

import Foundation
import GoogleAPI
import GoogleOAuth
import ReactiveSwift
import Result

extension GoogleAPI {
    
    public final class TokenProvider: GoogleAPITokenProvider {
        
        public enum ServiceAccountCredentials {
            
            case file(URL)
            case data(Data)
            
        }
        
        public enum AuthenticationMethod {
            
            case oauth(server: BotEngine.HTTPServer, credentialsFilename: String)
            case serviceAccount(credentials: ServiceAccountCredentials, delegatedAccount: String?)
            
        }
        
        private let authenticationMethod: AuthenticationMethod
        private let scopes: [String]
        
        private let queue = DispatchQueue(label: "GoogleAPI.TokenProviderQueue")
        private var token: GoogleAPI.Token? {
            set {
                queue.sync {
                    _token = newValue
                }
            }
            get {
                return queue.sync { _token }
            }
        }
        private var _token: GoogleAPI.Token?
        
        public init(scopes: [String], authenticationMethod: AuthenticationMethod) {
            self.scopes = scopes
            self.authenticationMethod = authenticationMethod
        }
        
        public convenience init(credentials: ServiceAccountCredentials, scopes: [String], delegatedAccount: String? = .none) {
            self.init(scopes: scopes, authenticationMethod: .serviceAccount(
                credentials: credentials,
                delegatedAccount: delegatedAccount)
            )
        }
        
        public convenience init(server: BotEngine.HTTPServer, credentialsFilename: String, scopes: [String]) {
            self.init(scopes: scopes, authenticationMethod: .oauth(
                server: server,
                credentialsFilename: credentialsFilename)
            )
        }
        
        public func fetchToken() -> SignalProducer<GoogleAPI.Token, AnyError> {
            if let token = self.token, !token.isExpired() {
                return .init(value: token)
            }
            if token?.isExpired() ?? false {
                print("INFO - Google API access token is expired.")
            }
            
            let tokenProducer: SignalProducer<GoogleAPI.Token, AnyError>
            switch authenticationMethod {
            case .oauth(let server, let credentialsFilename):
                tokenProducer = login(with: server, credentialsFilename: credentialsFilename)
            case .serviceAccount(let credentials, let delegatedAccount):
                tokenProducer = login(credentials: credentials, delegatedAccount: delegatedAccount)
            }
            return tokenProducer.on(value: { self.token = $0 })
        }
        
    }
    
}


fileprivate let tokenFilename =  ".google_api_token"

fileprivate extension GoogleAPI.TokenProvider {
    
    func login(with server: BotEngine.HTTPServer, credentialsFilename: String) -> SignalProducer<GoogleAPI.Token, AnyError> {
        guard let tokenProvider = BrowserTokenProvider(
            credentials: credentialsFilename,
            token: tokenFilename,
            oauthCallbackBaseURL: server.host) else {
                return .init(errorMessage: "Unable to create BrowserTokenProvider")
        }
        
        return SignalProducer { [scopes = self.scopes] observer, lifeTime in
            print("INFO - Fetching Google API access token using OAuth flow")
            server.registerTemporaryHandler(forPath: tokenProvider.callbackPath) { [queue = self.queue] request in
                guard let urlComponents = request.urlComponents else {
                    print("WARN - URL components could not be created for URL '\(request.url.absoluteString)'")
                    observer.send(errorMessage: "Invalid auth server response")
                    return .init(value: .badRequest)
                }
                
                let code = Code(urlComponents: urlComponents)
                return tokenProvider.exchangeCodeAndSaveToken(code: code, queue: queue)
                    .on(failed: observer.send(error:), value: observer.send(value:))
                    .map { _ in .success("Success! Token received.\n") }
            }
            
            do {
                try tokenProvider.signIn(scopes: scopes)
            } catch let error {
                observer.send(error: AnyError(error))
            }
        }
    }
    
    func login(credentials: ServiceAccountCredentials, delegatedAccount: String?)
        -> SignalProducer<GoogleAPI.Token, AnyError> {
        guard let tokenProvider = credentials.provider(with: scopes) else {
            return .init(error: AnyError(BotEngine.ErrorMessage(message: "Unable to create GoogleAuth token provider")))
        }

        return SignalProducer { observer, _ in
            print("INFO - Fetching Google API access token using service account credentials")
            do {
                if delegatedAccount != nil {
                    print("INFO - Delegating GCloud service account to '\(delegatedAccount!)'")
                }
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
    
}

fileprivate extension BrowserTokenProvider {
    
    func exchangeCodeAndSaveToken(code: Code, queue: DispatchQueue) -> SignalProducer<GoogleAPI.Token, AnyError> {
        return SignalProducer { observer, _ in
            queue.async {
                do {
                    try self.exchange(code: code)
                    try self.saveToken(tokenFilename)
                    if let token = self.token?.asGoogleToken {
                        observer.send(value: token)
                        observer.sendCompleted()
                    } else {
                        observer.send(errorMessage: "Unable to obtain access token from auth provider")
                    }
                } catch let error {
                    observer.send(error: AnyError(error))
                }
            }
        }
    }
    
}

fileprivate extension GoogleAPI.TokenProvider.ServiceAccountCredentials {
    
    func provider(with scopes: [String]) -> GoogleOAuth.TokenProvider? {
        switch self {
        case .data(let credentialsData):
            return ServiceAccountTokenProvider(credentialsData: credentialsData, scopes: scopes)
        case .file(let credentialsFile):
            return ServiceAccountTokenProvider(credentialsURL: credentialsFile, scopes: scopes)
        }
    }
    
}

fileprivate extension Token {
    
    var asGoogleToken: GoogleAPI.Token? {
        guard let tokenType = self.TokenType, let tokenValue = self.AccessToken,
            let expiresIn = self.ExpiresIn else {
                return nil
        }
        return GoogleAPI.Token(type: tokenType, value: tokenValue, expiresIn: expiresIn)
    }
    
}
