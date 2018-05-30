//
//  AutoProtocols.swift
//  GoogleAPI
//
//  Created by Guido Marucci Blas on 5/30/18.
//

import Foundation

internal protocol AutoDecodable: Decodable {}
internal protocol AutoEncodable: Encodable {}
internal protocol AutoCodable: AutoDecodable, AutoEncodable {}
internal protocol AutoEquatable { }
