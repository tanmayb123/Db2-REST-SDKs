//
//  StatementService.swift
//  Db2RESTNative-CodeGen-Swift
//
//  Created by Tanmay Bakshi on 2022-01-19.
//

import SwiftSyntax

struct StatementService: Service, Codable {
    let formalName: String
    let formalVersion: String
    
    let requestName: String
    let parameters: [Parameter]
    
    func generatePrimaryFunctionBody() -> [CodeBlockItemSyntax] {
        var codeComponents: [Syntax] = []
        codeComponents.append(
            Syntax(SyntaxFactory.makeVariableDecl(
                attributes: nil,
                modifiers: nil,
                letOrVarKeyword: SyntaxFactory.makeLetKeyword(),
                bindings: SyntaxFactory.makePatternBindingList([
                    SyntaxFactory.makePatternBinding(
                        pattern: PatternSyntax(SyntaxFactory.makeIdentifierPattern(
                            identifier: SyntaxFactory.makeIdentifier("parameters")
                        )),
                        typeAnnotation: SyntaxFactory.makeTypeAnnotation(
                            colon: SyntaxFactory.makeColonToken(),
                            type: getParametersDictionaryType()
                        ),
                        initializer: SyntaxFactory.makeInitializerClause(
                            equal: SyntaxFactory.makeEqualToken(),
                            value: ExprSyntax(SyntaxFactory.makeFunctionCallExpr(
                                calledExpression: ExprSyntax(SyntaxFactory.makeIdentifierExpr(
                                    identifier: SyntaxFactory.makeIdentifier("\(requestName)_paramConversion"),
                                    declNameArguments: nil
                                )),
                                leftParen: SyntaxFactory.makeLeftParenToken(),
                                argumentList: generateParameterElementList(),
                                rightParen: SyntaxFactory.makeRightParenToken(),
                                trailingClosure: nil,
                                additionalTrailingClosures: nil
                            ))
                        ),
                        accessor: nil,
                        trailingComma: nil
                    )
                ])
            ))
        )
        codeComponents.append(
            Syntax(SyntaxFactory.makeVariableDecl(
                attributes: nil,
                modifiers: nil,
                letOrVarKeyword: SyntaxFactory.makeLetKeyword(),
                bindings: SyntaxFactory.makePatternBindingList([
                    SyntaxFactory.makePatternBinding(
                        pattern: PatternSyntax(SyntaxFactory.makeIdentifierPattern(
                            identifier: SyntaxFactory.makeIdentifier("dbResult")
                        )),
                        typeAnnotation: SyntaxFactory.makeTypeAnnotation(
                            colon: SyntaxFactory.makeColonToken(),
                            type: SyntaxFactory.makeTypeIdentifier("Db2REST.Response<Nothing>?")
                        ),
                        initializer: SyntaxFactory.makeInitializerClause(
                            equal: SyntaxFactory.makeEqualToken(),
                            value: ExprSyntax(SyntaxFactory.makeTryExpr(
                                tryKeyword: SyntaxFactory.makeTryKeyword(),
                                questionOrExclamationMark: nil,
                                expression: ExprSyntax(SyntaxFactory.makeAwaitExpr(
                                    awaitKeyword: SyntaxFactory.makeIdentifier("await"),
                                    expression: ExprSyntax(SyntaxFactory.makeFunctionCallExpr(
                                        calledExpression: ExprSyntax(SyntaxFactory.makeMemberAccessExpr(
                                            base: ExprSyntax(SyntaxFactory.makeIdentifierExpr(
                                                identifier: SyntaxFactory.makeIdentifier("db"),
                                                declNameArguments: nil
                                            )),
                                            dot: SyntaxFactory.makePeriodToken(),
                                            name: SyntaxFactory.makeIdentifier("runSyncJob"),
                                            declNameArguments: nil
                                        )),
                                        leftParen: SyntaxFactory.makeLeftParenToken(),
                                        argumentList: SyntaxFactory.makeTupleExprElementList([
                                            SyntaxFactory.makeTupleExprElement(
                                                label: SyntaxFactory.makeIdentifier("service"),
                                                colon: SyntaxFactory.makeColonToken(),
                                                expression: ExprSyntax(SyntaxFactory.makeStringLiteralExpr(formalName)),
                                                trailingComma: SyntaxFactory.makeCommaToken()
                                            ),
                                            SyntaxFactory.makeTupleExprElement(
                                                label: SyntaxFactory.makeIdentifier("version"),
                                                colon: SyntaxFactory.makeColonToken(),
                                                expression: ExprSyntax(SyntaxFactory.makeStringLiteralExpr(formalVersion)),
                                                trailingComma: SyntaxFactory.makeCommaToken()
                                            ),
                                            SyntaxFactory.makeTupleExprElement(
                                                label: SyntaxFactory.makeIdentifier("parameters"),
                                                colon: SyntaxFactory.makeColonToken(),
                                                expression: ExprSyntax(SyntaxFactory.makeVariableExpr("parameters")),
                                                trailingComma: nil
                                            )
                                        ]),
                                        rightParen: SyntaxFactory.makeRightParenToken(),
                                        trailingClosure: nil,
                                        additionalTrailingClosures: nil
                                    ))
                                ))
                            ))
                        ),
                        accessor: nil,
                        trailingComma: nil
                    )
                ])
            ))
        )
        codeComponents.append(
            Syntax(SyntaxFactory.makeReturnStmt(
                returnKeyword: SyntaxFactory.makeReturnKeyword(),
                expression: ExprSyntax(SyntaxFactory.makeVariableExpr("dbResult"))
            ))
        )
        return codeComponents.map { decl in
            SyntaxFactory.makeCodeBlockItem(
                item: decl,
                semicolon: nil,
                errorTokens: nil
            )
        }
    }
    
    func generateFunction() -> FunctionDeclSyntax {
        SyntaxFactory.makeFunctionDecl(
            attributes: nil,
            modifiers: nil,
            funcKeyword: SyntaxFactory.makeFuncKeyword(),
            identifier: SyntaxFactory.makeIdentifier("\(requestName)"),
            genericParameterClause: nil,
            signature: SyntaxFactory.makeFunctionSignature(
                input: generateParameterClause(withDb: true),
                asyncOrReasyncKeyword: nil,
                throwsOrRethrowsKeyword: getAsyncThrowsKeyword(),
                output: SyntaxFactory.makeReturnClause(
                    arrow: SyntaxFactory.makeArrowToken(),
                    returnType: TypeSyntax(SyntaxFactory.makeOptionalType(
                        wrappedType: SyntaxFactory.makeTypeIdentifier("Db2REST.Response<Nothing>"),
                        questionMark: SyntaxFactory.makeInfixQuestionMarkToken()
                    ))
                )
            ),
            genericWhereClause: nil,
            body: SyntaxFactory.makeCodeBlock(
                leftBrace: SyntaxFactory.makeLeftBraceToken(),
                statements: SyntaxFactory.makeCodeBlockItemList(generatePrimaryFunctionBody()),
                rightBrace: SyntaxFactory.makeRightBraceToken()
            )
        )
    }
    
    func generateCode() -> [CodeBlockItemSyntax] {
        let paramsFunction = generateParametersFunction()
        let syncFunction = generateFunction()
        
        return [
            SyntaxFactory.makeCodeBlockItem(item: Syntax(paramsFunction), semicolon: nil, errorTokens: nil),
            SyntaxFactory.makeCodeBlockItem(item: Syntax(syncFunction), semicolon: nil, errorTokens: nil),
        ]
    }
}
