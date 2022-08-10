//
//  Parameter.swift
//  Db2RESTNative-CodeGen-Swift
//
//  Created by Tanmay Bakshi on 2022-01-19.
//

import SwiftSyntax

enum ParameterKind {
    case sql
    case json
}

struct Parameter: Codable {
    var formalName: String
    var name: String
    var sqlType: SQLType
    var jsonType: Db2RESTType
    var nullable: Bool
    
    func swiftType(kind: ParameterKind) -> TypeSyntax {
        var type: TypeSyntax
        switch kind {
        case .sql:
            type = sqlType.swiftType()
        case .json:
            type = jsonType.swiftType()
        }
        if nullable {
            type = TypeSyntax(Syntax(SyntaxFactory.makeOptionalType(wrappedType: type, questionMark: SyntaxFactory.makeInfixQuestionMarkToken())))!
        }
        return type
    }
    
    func converterFunctionCall(withSelf: Bool) -> FunctionCallExprSyntax {
        let selfMemberAccess: ExprSyntax
        if withSelf {
            selfMemberAccess = ExprSyntax(SyntaxFactory.makeMemberAccessExpr(
                base: ExprSyntax(SyntaxFactory.makeIdentifierExpr(
                    identifier: SyntaxFactory.makeIdentifier("self"),
                    declNameArguments: nil
                )),
                dot: SyntaxFactory.makePeriodToken(),
                name: SyntaxFactory.makeIdentifier(name),
                declNameArguments: nil
            ))
        } else {
            selfMemberAccess = ExprSyntax(SyntaxFactory.makeVariableExpr(name))
        }
        return SyntaxFactory.makeFunctionCallExpr(
            calledExpression: getConvertFunctionMemberAccess(),
            leftParen: SyntaxFactory.makeLeftParenToken(),
            argumentList: SyntaxFactory.makeTupleExprElementList([
                SyntaxFactory.makeTupleExprElement(label: nil, colon: nil, expression: selfMemberAccess, trailingComma: nil)
            ]),
            rightParen: SyntaxFactory.makeRightParenToken(),
            trailingClosure: nil,
            additionalTrailingClosures: nil
        )
    }
}
