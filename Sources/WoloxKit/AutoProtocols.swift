//
//  AutoProtocols.swift
//  AuthPackageDescription
//
//  Created by Guido Marucci Blas on 4/15/18.
//

internal protocol AutoDecodable: Decodable {}
internal protocol AutoEncodable: Encodable {}
internal protocol AutoCodable: AutoDecodable, AutoEncodable {}
internal protocol AutoEquatable { }
internal protocol AutoInstanceVariableCounter { }
internal protocol AutoInstanceVariableEnumerator { }
internal protocol AutoSnakeCaseCodingKey { }
