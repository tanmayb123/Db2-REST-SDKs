//
//  Types.swift
//  Db2RESTNative-CodeGen-Swift
//
//  Created by Tanmay Bakshi on 2022-01-19.
//

import SwiftSyntax

enum SQLType: String, Codable {
    static var swiftTypes: [Self: String] = [
        .VARCHAR: "String",
        .CHARACTER: "String",
        .SMALLINT: "Int16",
        .INTEGER: "Int32",
        .BIGINT: "Int",
        .DATE: "Date",
        .DOUBLE: "Double"
    ]
    
    case VARCHAR
    case CHARACTER
    case DATE
    case CLOB
    case TIME
    case TIMESTAMP
    case INTEGER
    case SMALLINT
    case BIGINT
    case DECIMAL
    case NUMERIC
    case DOUBLE
    case FLOAT
    case DECFLOAT
    case BOOLEAN
    
    func swiftType() -> TypeSyntax {
        return SyntaxFactory.makeTypeIdentifier(Self.swiftTypes[self]!)
    }
}

enum Db2RESTType: String, Codable {
    static var swiftTypes: [Self: String] = [
        .string: "String",
        .integer: "Int",
        .number: "Double",
        .boolean: "Bool"
    ]
    
    case string
    case integer
    case number
    case boolean
    
    func swiftType() -> TypeSyntax {
        return SyntaxFactory.makeTypeIdentifier(Self.swiftTypes[self]!)
    }
}
