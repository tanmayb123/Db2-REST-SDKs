//
//  QueryService.swift
//  Db2RESTNative-CodeGen-Swift
//
//  Created by Tanmay Bakshi on 2022-01-19.
//

import SwiftSyntax

struct QueryService: Service, Codable {
    let formalName: String
    let formalVersion: String
    
    let requestName: String
    let parameters: [Parameter]
    
    let responseName: String
    let columns: [Parameter]
    
    func generateI2EConverterFunction() -> FunctionDeclSyntax {
        SyntaxFactory.makeFunctionDecl(
            attributes: nil,
            modifiers: nil,
            funcKeyword: SyntaxFactory.makeFuncKeyword(),
            identifier: SyntaxFactory.makeIdentifier("convert"),
            genericParameterClause: nil,
            signature: SyntaxFactory.makeFunctionSignature(
                input: SyntaxFactory.makeParameterClause(
                    leftParen: SyntaxFactory.makeLeftParenToken(),
                    parameterList: SyntaxFactory.makeFunctionParameterList([]),
                    rightParen: SyntaxFactory.makeRightParenToken()
                ),
                asyncOrReasyncKeyword: nil,
                throwsOrRethrowsKeyword: nil,
                output: SyntaxFactory.makeReturnClause(
                    arrow: SyntaxFactory.makeArrowToken(),
                    returnType: SyntaxFactory.makeTypeIdentifier(responseName)
                )
            ),
            genericWhereClause: nil,
            body: SyntaxFactory.makeCodeBlock(
                leftBrace: SyntaxFactory.makeLeftBraceToken(),
                statements: SyntaxFactory.makeCodeBlockItemList([
                    SyntaxFactory.makeCodeBlockItem(
                        item: Syntax(SyntaxFactory.makeReturnStmt(
                            returnKeyword: SyntaxFactory.makeReturnKeyword(),
                            expression: ExprSyntax(SyntaxFactory.makeFunctionCallExpr(
                                calledExpression: ExprSyntax(SyntaxFactory.makeIdentifierExpr(
                                    identifier: SyntaxFactory.makeIdentifier(responseName),
                                    declNameArguments: nil
                                )),
                                leftParen: SyntaxFactory.makeLeftParenToken(),
                                argumentList: SyntaxFactory.makeTupleExprElementList(columns.enumerated().map { (idx, column) in
                                    SyntaxFactory.makeTupleExprElement(
                                        label: SyntaxFactory.makeIdentifier(column.name),
                                        colon: SyntaxFactory.makeColonToken(),
                                        expression: ExprSyntax(column.converterFunctionCall(withSelf: true)),
                                        trailingComma: idx == (columns.count - 1) ? nil : SyntaxFactory.makeCommaToken()
                                    )
                                }),
                                rightParen: SyntaxFactory.makeRightParenToken(),
                                trailingClosure: nil,
                                additionalTrailingClosures: nil
                            ))
                        )),
                        semicolon: nil,
                        errorTokens: nil
                    )
                ]),
                rightBrace: SyntaxFactory.makeRightBraceToken()
            )
        )
    }
    
    func generateStructMembers(kind: ParameterKind) -> [MemberDeclListItemSyntax] {
        var decls: [MemberDeclListItemSyntax] = []
        if kind == .json {
            decls.append(
                SyntaxFactory.makeMemberDeclListItem(
                    decl: DeclSyntax(SyntaxFactory.makeEnumDecl(
                        attributes: nil,
                        modifiers: nil,
                        enumKeyword: SyntaxFactory.makeEnumKeyword(),
                        identifier: SyntaxFactory.makeIdentifier("CodingKeys"),
                        genericParameters: nil,
                        inheritanceClause: SyntaxFactory.makeTypeInheritanceClause(
                            colon: SyntaxFactory.makeColonToken(),
                            inheritedTypeCollection: SyntaxFactory.makeInheritedTypeList([
                                SyntaxFactory.makeInheritedType(
                                    typeName: SyntaxFactory.makeTypeIdentifier("String"),
                                    trailingComma: SyntaxFactory.makeCommaToken()
                                ),
                                SyntaxFactory.makeInheritedType(
                                    typeName: SyntaxFactory.makeTypeIdentifier("CodingKey"),
                                    trailingComma: nil
                                ),
                            ])
                        ),
                        genericWhereClause: nil,
                        members: SyntaxFactory.makeMemberDeclBlock(
                            leftBrace: SyntaxFactory.makeLeftBraceToken(),
                            members: SyntaxFactory.makeMemberDeclList(columns.map { column in
                                SyntaxFactory.makeMemberDeclListItem(
                                    decl: DeclSyntax(SyntaxFactory.makeEnumCaseDecl(
                                        attributes: nil,
                                        modifiers: nil,
                                        caseKeyword: SyntaxFactory.makeCaseKeyword(),
                                        elements: SyntaxFactory.makeEnumCaseElementList([
                                            SyntaxFactory.makeEnumCaseElement(
                                                identifier: SyntaxFactory.makeIdentifier(column.name),
                                                associatedValue: nil,
                                                rawValue: SyntaxFactory.makeInitializerClause(
                                                    equal: SyntaxFactory.makeEqualToken(),
                                                    value: ExprSyntax(SyntaxFactory.makeStringLiteralExpr(column.formalName))
                                                ),
                                                trailingComma: nil
                                            )
                                        ])
                                    )),
                                    semicolon: nil
                                )
                            }),
                            rightBrace: SyntaxFactory.makeRightBraceToken()
                        )
                    )),
                    semicolon: nil
                )
            )
        }
        decls += columns.enumerated().map { (idx, column) in
            SyntaxFactory.makeMemberDeclListItem(
                decl: DeclSyntax(Syntax(SyntaxFactory.makeVariableDecl(
                    attributes: nil,
                    modifiers: nil,
                    letOrVarKeyword: SyntaxFactory.makeLetKeyword(),
                    bindings: SyntaxFactory.makePatternBindingList([
                        SyntaxFactory.makePatternBinding(
                            pattern: PatternSyntax(SyntaxFactory.makeIdentifierPattern(
                                identifier: SyntaxFactory.makeIdentifier(column.name)
                            )),
                            typeAnnotation: SyntaxFactory.makeTypeAnnotation(
                                colon: SyntaxFactory.makeColonToken(),
                                type: column.swiftType(kind: kind)
                            ),
                            initializer: nil, accessor: nil,
                            trailingComma: nil
                        )
                    ])
                )))!,
                semicolon: nil
            )
        }
        return decls
    }
    
    func generateCodableReturnStructure() -> StructDeclSyntax {
        var members = generateStructMembers(kind: .json)
        members.append(SyntaxFactory.makeMemberDeclListItem(
            decl: DeclSyntax(generateI2EConverterFunction()),
            semicolon: nil
        ))
        return SyntaxFactory.makeStructDecl(
            attributes: nil,
            modifiers: nil,
            structKeyword: SyntaxFactory.makeStructKeyword(),
            identifier: SyntaxFactory.makeIdentifier(responseName + "_internal"),
            genericParameterClause: nil,
            inheritanceClause: SyntaxFactory.makeTypeInheritanceClause(
                colon: SyntaxFactory.makeColonToken(),
                inheritedTypeCollection: SyntaxFactory.makeInheritedTypeList([
                    SyntaxFactory.makeInheritedType(
                        typeName: SyntaxFactory.makeTypeIdentifier("Codable"),
                        trailingComma: SyntaxFactory.makeCommaToken()
                    ),
                    SyntaxFactory.makeInheritedType(
                        typeName: SyntaxFactory.makeTypeIdentifier("Swiftifiable"),
                        trailingComma: nil
                    ),
                ])
            ),
            genericWhereClause: nil,
            members: SyntaxFactory.makeMemberDeclBlock(
                leftBrace: SyntaxFactory.makeLeftBraceToken(),
                members: SyntaxFactory.makeMemberDeclList(members),
                rightBrace: SyntaxFactory.makeRightBraceToken()
            )
        )
    }
    
    func generateExternalReturnStructure() -> StructDeclSyntax {
        var members = generateStructMembers(kind: .sql)
        members.insert(
            SyntaxFactory.makeMemberDeclListItem(
                decl: DeclSyntax(Syntax(generateCodableReturnStructure()))!,
                semicolon: nil
            ),
            at: 0
        )
        let structDecl = SyntaxFactory.makeStructDecl(
            attributes: nil,
            modifiers: nil,
            structKeyword: SyntaxFactory.makeStructKeyword(),
            identifier: SyntaxFactory.makeIdentifier(responseName),
            genericParameterClause: nil,
            inheritanceClause: nil,
            genericWhereClause: nil,
            members: SyntaxFactory.makeMemberDeclBlock(
                leftBrace: SyntaxFactory.makeLeftBraceToken(),
                members: SyntaxFactory.makeMemberDeclList(members),
                rightBrace: SyntaxFactory.makeRightBraceToken()
            )
        )
        return structDecl
    }
    
    func generatePrimaryFunctionBody(sync: Bool) -> [CodeBlockItemSyntax] {
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
                            type: SyntaxFactory.makeTypeIdentifier(sync ? "Db2REST.Response<\(responseName).\(responseName)_internal>?" : "Db2REST.Job<\(responseName).\(responseName)_internal>")
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
                                            name: SyntaxFactory.makeIdentifier(sync ? "runSyncJob" : "runAsyncJob"),
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
                expression: ExprSyntax(SyntaxFactory.makeFunctionCallExpr(
                    calledExpression: ExprSyntax(SyntaxFactory.makeMemberAccessExpr(
                        base: ExprSyntax(SyntaxFactory.makeVariableExpr(sync ? "dbResult?" : "dbResult")),
                        dot: SyntaxFactory.makePeriodToken(),
                        name: SyntaxFactory.makeIdentifier("convert"),
                        declNameArguments: nil
                    )),
                    leftParen: SyntaxFactory.makeLeftParenToken(),
                    argumentList: SyntaxFactory.makeTupleExprElementList([]),
                    rightParen: SyntaxFactory.makeRightParenToken(),
                    trailingClosure: nil,
                    additionalTrailingClosures: nil
                ))
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
    
    func generateFunction(sync: Bool) -> FunctionDeclSyntax {
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
                        wrappedType: SyntaxFactory.makeTypeIdentifier(sync ? "Db2REST.Response<\(responseName)>" : "SwiftifiedJob<\(responseName).\(responseName)_internal>"),
                        questionMark: SyntaxFactory.makeInfixQuestionMarkToken()
                    ))
                )
            ),
            genericWhereClause: nil,
            body: SyntaxFactory.makeCodeBlock(
                leftBrace: SyntaxFactory.makeLeftBraceToken(),
                statements: SyntaxFactory.makeCodeBlockItemList(generatePrimaryFunctionBody(sync: sync)),
                rightBrace: SyntaxFactory.makeRightBraceToken()
            )
        )
    }
    
    func generateCode() -> [CodeBlockItemSyntax] {
        let structures = generateExternalReturnStructure()
        let paramsFunction = generateParametersFunction()
        let syncFunction = generateFunction(sync: true)
        let asyncFunction = generateFunction(sync: false)
        
        return [
            SyntaxFactory.makeCodeBlockItem(item: Syntax(structures), semicolon: nil, errorTokens: nil),
            SyntaxFactory.makeCodeBlockItem(item: Syntax(paramsFunction), semicolon: nil, errorTokens: nil),
            SyntaxFactory.makeCodeBlockItem(item: Syntax(syncFunction), semicolon: nil, errorTokens: nil),
            SyntaxFactory.makeCodeBlockItem(item: Syntax(asyncFunction), semicolon: nil, errorTokens: nil),
        ]
    }
}
