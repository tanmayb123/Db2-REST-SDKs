//
//  Global.swift
//  Db2RESTNative-CodeGen-Swift
//
//  Created by Tanmay Bakshi on 2022-01-19.
//

import SwiftSyntax

func getConvertFunctionMemberAccess() -> ExprSyntax {
    ExprSyntax(SyntaxFactory.makeMemberAccessExpr(
        base: ExprSyntax(SyntaxFactory.makeIdentifierExpr(
            identifier: SyntaxFactory.makeIdentifier("Db2NativeUtils"),
            declNameArguments: nil
        )),
        dot: SyntaxFactory.makePeriodToken(),
        name: SyntaxFactory.makeIdentifier("convert"),
        declNameArguments: nil
    ))
}

func getParametersDictionaryType() -> TypeSyntax {
    TypeSyntax(SyntaxFactory.makeDictionaryType(
        leftSquareBracket: SyntaxFactory.makeLeftSquareBracketToken(),
        keyType: SyntaxFactory.makeTypeIdentifier("String"),
        colon: SyntaxFactory.makeColonToken(),
        valueType: SyntaxFactory.makeTypeIdentifier("Any"),
        rightSquareBracket: SyntaxFactory.makeRightSquareBracketToken()
    ))
}

func getAsyncThrowsKeyword() -> TokenSyntax {
    SyntaxFactory.makeThrowsKeyword(leadingTrivia: .garbageText(" async "))
}

func getDbParameter(comma: Bool) -> FunctionParameterSyntax {
    SyntaxFactory.makeFunctionParameter(
        attributes: nil,
        firstName: SyntaxFactory.makeIdentifier("db"),
        secondName: nil,
        colon: SyntaxFactory.makeColonToken(),
        type: SyntaxFactory.makeTypeIdentifier("Db2REST"),
        ellipsis: nil,
        defaultArgument: nil,
        trailingComma: comma ? SyntaxFactory.makeCommaToken() : nil
    )
}
