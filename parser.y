%{
    #include "parser.h"
%}

%define parse.error verbose

%union {
	SymbolInfo* symbolInfo;
}

%token RETURN VOID FLOAT INT WHILE FOR IF ELSE INCOP DECOP ASSIGNOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON PRINTLN UNRECOGNIZED

%token <symbolInfo> ID CONST_INT CONST_FLOAT ADDOP MULOP RELOP LOGICOP

%type <symbolInfo> start program unit var_declaration variable type_specifier declaration_list expression_statement func_declaration parameter_list func_definition compound_statement statements unary_expression factor statement arguments expression logic_expression simple_expression rel_expression term argument_list

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
{
	//done

	yacclogfile << "Scope #" << symbolTable.getCurrentScopeID() << " Exited" << std::endl;
	yacclogfile << symbolTable.printAllScopeTable() << std::endl << std::endl;
	tabSpace--;

	std::string codeText($1->getName());
	logCode(codeText, "start : program");
	$$ = new SymbolInfo(codeText, "");
}
;




program : program unit 
{
	//done
	std::string codeText($1->getName() + "\n"
						+$2->getName());
	logCode(codeText, "program : program unit");
	$$ = new SymbolInfo(codeText, "");
}

| unit
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "program : unit");
	$$ = new SymbolInfo(codeText, "");
}
;




unit : var_declaration 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "unit : var_declaration");
	$$ = new SymbolInfo(codeText, "");
}


| func_declaration 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "unit : func_declaration");
	$$ = new SymbolInfo(codeText, "");
}


| func_definition 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "unit : func_definition");
	$$ = new SymbolInfo(codeText, "");
}
|UNRECOGNIZED
{
	errorLog("Unrecognized Character");
	$$ = new SymbolInfo("", "VOID");
}
|error SEMICOLON 
{
	$$ = new SymbolInfo("", "VOID");
}
|error RCURL 
{
	$$ = new SymbolInfo("", "VOID");
}
;	




func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON 
{
	//done
	SymbolInfo* 
	globalAvailability = symbolTable.lookGlobalScope($2->getName());

	if(globalAvailability != nullptr)
	{
		errorLog("Multiple declaration of same name " + $2->getName());
	}
	else
	{
		std::vector<SymbolInfo> vars = $4->getParamList();
		bool voidFlag = false;
		for(int i = 0; i < vars.size(); i++)
		{
			if(vars[i].getType() == "ID_VOID")
			{
				errorLog("Parameters cannot be void");
				voidFlag = true;
				break;
			}
		}
		if(!voidFlag)
		{
			symbolTable.insert($2->getName(), "FUNC_" + $1->getName(), vars);
			if($1->getName() == "INT") $1->setName("int");
			if($1->getName() == "FLOAT") $1->setName("float");
			if($1->getName() == "VOID") $1->setName("void");
		}
	}

	std::string codeText($1->getName() + " "
						+$2->getName()
						+"("
						+$4->getName()
						+");\n");
	logCode(codeText, "func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
	$$ = new SymbolInfo(codeText, "");
	symbolTable.enterScope();
	symbolTable.exitScope();

}


| type_specifier ID LPAREN RPAREN SEMICOLON 
{
	//done
	SymbolInfo* 
	globalAvailability = symbolTable.lookGlobalScope($2->getName());

	if(globalAvailability != nullptr){
		errorLog("Multiple declaration of same name " + $2->getName());
	}else{
		symbolTable.insert($2->getName(), "FUNC_" + $1->getName());
		if($1->getName() == "INT") $1->setName("int");
		if($1->getName() == "FLOAT") $1->setName("float");
		if($1->getName() == "VOID") $1->setName("void");
	}

	std::string codeText($1->getName() + " "
						+$2->getName()
						+"();");
	logCode(codeText, "func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON");
	$$ = new SymbolInfo(codeText, "");

	symbolTable.enterScope();
	symbolTable.exitScope();
}
;




func_definition : type_specifier ID LPAREN parameter_list RPAREN 
{
	//done

	/* global variables to check when function is returning */
	currentReturnType = $1->getName();
	currentFunction =  $2->getName();
	functionHasReturned = false;

	SymbolInfo* 
	globalAvailability = symbolTable.lookGlobalScope($2->getName());

	/* decl for parameters included in declaration, defn for parameters included in definition */
	std::vector<SymbolInfo> decl;
	// if check to make sure that decl only get vector if there is one to pull out from
	if(globalAvailability != nullptr) decl = globalAvailability->getParamList(); 
	std::vector<SymbolInfo> defn = $4->getParamList();

	/* 
	Definable Function = check if the function is already defined
	Insert Parameter Flag = every thing is fine, insert the parameters to the symbol table
	*/
	bool definableFunction = true;
	bool insertParameterFlag = false;

	
	if(globalAvailability != nullptr)
	{
		if(globalAvailability->isDefined()) definableFunction = false; //function is already defined
	}

	/* checking for multiple definition */
	if(!definableFunction)
	{
		errorLog("Multiple definition of same function " + $2->getName());
	}
	else
	{
		/* trying to define something that has other declaration */
		if(globalAvailability != nullptr && !isFunction(globalAvailability->getType()))
		{
			errorLog("Multiple declaration of " + $2->getName());
		}
		else
		{
			/* return type mismatch */
			if(globalAvailability != nullptr && 
			globalAvailability->getType() != "FUNC_" + $1->getName())
			{
				errorLog("Return type mismatch with function declaration in function " + $2->getName());
			}
			else
			{
				/* Checking the parameter types */
				bool parameterMismatch = false;
				bool differentAmountofParameter = false;
				if(globalAvailability != nullptr){
					if(decl.size() != defn.size()) differentAmountofParameter = true; //parameter amount
					else
					{
						for(int i = 0; i < decl.size(); i++){ //parameter amount
							if(decl[i].getType() != defn[i].getType())
							{
								parameterMismatch = true;
								break;
							}
						}
					}
				}

				if(parameterMismatch)
				{
					errorLog("Parameter mismatch");
				}else if(differentAmountofParameter){
					errorLog("Total number of arguments mismatch with declaration in function " + $2->getName());
				}
				else
				{
					/* now check if every parameter has name */
					bool parameterNoName = false;
					for(int i = 0; i < defn.size(); i++){
						if(defn[i].getName() == "")
						{
							parameterNoName = true;
							break;
						}
					}
					if(parameterNoName)
					{
						errorLog("Function Definition with one parameter missing name");
					}
					else
					{
						/* inserting parameters to symbolTable */
						//Global Availability = nullptr means that the function isn't declared before, so it needs to be included in the symboltable
						if(globalAvailability == nullptr)
						{
							symbolTable.insert($2->getName(), "FUNC_" + $1->getName(), defn);
						}
						insertParameterFlag = true; // should not include parameters to symboltable here, must do it after entering a new scope
						symbolTable.define($2->getName());
					}
				}
			}
		}
	}
	symbolTable.enterScope();
	tabSpace++;
	for(int i = 0; i < defn.size(); i++){
		if(!symbolTable.insert(defn[i].getName(), defn[i].getType())) errorLog("Multiple declaration of " + defn[i].getName() + " in parameter");
	}
	//code logs are included in next part
} 
compound_statement 
{
	if(!functionHasReturned && currentReturnType != "VOID"){
		errorLog("Function didn't return any value " + $2->getName());
	}

	yacclogfile << "Scope #" << symbolTable.getCurrentScopeID() << " Exited" << std::endl;
	yacclogfile << symbolTable.printAllScopeTable() << std::endl << std::endl;
	symbolTable.exitScope();
	tabSpace--;

	if($1->getName() == "INT") $1->setName("int");
	if($1->getName() == "FLOAT") $1->setName("float");
	if($1->getName() == "VOID") $1->setName("void");
	std::string codeText($1->getName() + " "
						+ $2->getName()
						+ "("
						+ $4->getName()
						+ ")\n" 
						+ $7->getName());
	logCode(codeText, "func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement");
	$$ = new SymbolInfo(codeText, "");
}


| type_specifier ID LPAREN RPAREN 
{
	//done

	/* global variables to check when function is returning */
	currentReturnType = $1->getName();
	currentFunction =  $2->getName();
	functionHasReturned = false;

	SymbolInfo* 
	globalAvailability = symbolTable.lookGlobalScope($2->getName());

	/* Definable Function = check if the function is already defined */
	bool definableFunction = true;


	if(globalAvailability != nullptr){
		if(globalAvailability->isDefined()) definableFunction = false;
	}

	/* checking for multiple definition */
	if(!definableFunction)
	{
		errorLog("Multiple definition of same function " + $2->getName());
	}
	else
	{
		/* trying to define something that has other declaration */
		if(globalAvailability != nullptr && !isFunction(globalAvailability->getType()))
		{
			errorLog("Multiple declaration of " + $2->getName());
		}
		else
		{
			/* return type mismatch */
			if(globalAvailability != nullptr && 
			globalAvailability->getType() != "FUNC_" + $1->getName())
			{
				errorLog("Return type mismatch with function declaration in function " + $2->getName());
			}
			else
			{
				/* the function has declaration with parameters */
				if(globalAvailability != nullptr && globalAvailability->getParamList().size() > 0)
				{
					errorLog("Parameter mismatch.");
				}
				else
				{
					if(globalAvailability == nullptr)
					{
						symbolTable.insert($2->getName(), "FUNC_" + $1->getName());
					}
					symbolTable.define($2->getName());
				}
			}
		}
	}
	symbolTable.enterScope();
	tabSpace++;
	//code logs are included in next part
} 
compound_statement 
{
	if(!functionHasReturned && currentReturnType != "VOID"){
		errorLog("Function didn't return any value " + $2->getName());
	}

	yacclogfile << "Scope #" << symbolTable.getCurrentScopeID() << " Exited" << std::endl;
	yacclogfile << symbolTable.printAllScopeTable() << std::endl << std::endl;
	symbolTable.exitScope();
	tabSpace--;

	if($1->getName() == "INT") $1->setName("int");
	if($1->getName() == "FLOAT") $1->setName("float");
	if($1->getName() == "VOID") $1->setName("void");
	std::string codeText($1->getName() + " "
						+ $2->getName()
						+ "()\n"
						+ $6->getName());
	logCode(codeText, "func_definition : type_specifier ID LPAREN RPAREN compound_statement");
	$$ = new SymbolInfo(codeText, "");
}
;




parameter_list : parameter_list COMMA type_specifier ID 
{
	//done
	$1->pushParam(SymbolInfo($4->getName(), "ID_" + $3->getName()));

	if($3->getName() == "VOID")
	{
		errorLog("Variable type cannot be void");
	}
	
	if($3->getName() == "INT") $3->setName("int");
	if($3->getName() == "FLOAT") $3->setName("float");
	if($3->getName() == "VOID") $3->setName("void");
	std::string codeText($1->getName() + "," + $3->getName() + " " + $4->getName());
	logCode(codeText, "parameter_list : parameter_list COMMA type_specifier ID");
	$1->setName(codeText);
	$$ = $1;
}


| parameter_list COMMA type_specifier 
{
	//done
	$1->pushParam(SymbolInfo("", "ID_" + $3->getName()));

	if($3->getName() == "VOID")
	{
		errorLog("Variable type cannot be void");
	}

	if($3->getName() == "INT") $3->setName("int");
	if($3->getName() == "FLOAT") $3->setName("float");
	if($3->getName() == "VOID") $3->setName("void");
	std::string codeText($1->getName() + "," + $3->getName());
	logCode(codeText, "parameter_list : parameter_list COMMA type_specifier");
	$1->setName(codeText);
	$$ = $1;
}


| type_specifier ID 
{
	//done
	std::vector<SymbolInfo>paramList;
	paramList.push_back(SymbolInfo($2->getName(), "ID_" + $1->getName()));

	if($1->getName() == "VOID")
	{
		errorLog("Variable type cannot be void");
	}

	if($1->getName() == "INT") $1->setName("int");
	if($1->getName() == "FLOAT") $1->setName("float");
	if($1->getName() == "VOID") $1->setName("void");
	std::string codeText($1->getName() + " " + $2->getName());
	logCode(codeText, "parameter_list : type_specifier ID");
	$$ = new SymbolInfo(codeText, "", paramList);
}


| type_specifier 
{
	//done
	std::vector<SymbolInfo>paramList;
	paramList.push_back(SymbolInfo("", "ID_" + $1->getName()));

	if($1->getName() == "VOID")
	{
		errorLog("Variable type cannot be void");
	}

	if($1->getName() == "INT") $1->setName("int");
	if($1->getName() == "FLOAT") $1->setName("float");
	if($1->getName() == "VOID") $1->setName("void");
	std::string codeText($1->getName());
	logCode(codeText, "parameter_list :  type_specifier");
	$$ = new SymbolInfo(codeText, "", paramList);
}
;




compound_statement : LCURL statements RCURL 
{
	//done
	tabSpace--;
	std::string codeText(indentGen() + "{\n" + $2->getName() + "\n" + indentGen() + "}");
	tabSpace++;
	logCode(codeText, "compound_statement : LCURL statements RCURL");
	$$ = new SymbolInfo(codeText, " ");
}


| LCURL RCURL 
{
	//done
	std::string codeText( "{}\n");
	logCode(codeText, "compound_statement : LCURL statements RCURL");
	$$ = new SymbolInfo(codeText, " ");
}
;




var_declaration : type_specifier declaration_list SEMICOLON 
{
	//done

	/* a variable with type void... interesting */
	if($1->getName() == "VOID")
	{
		errorLog("Variable type cannot be void");
	}
	else
	{
		std::vector<SymbolInfo> vars = $2->getParamList();
		for(int i = 0; i < vars.size(); i++){
			SymbolInfo* 
			globalAvailability = symbolTable.lookGlobalScope(vars[i].getName());
			if(	globalAvailability != nullptr && isFunction(globalAvailability->getType()) )
			{
				/* global function exist with same name */
				errorLog("Variable can't have the same name as function " + vars[i].getName());
			}else if(symbolTable.lookCurrentScope(vars[i].getName()) != nullptr){
				errorLog("Multiple declaration of " + vars[i].getName());
			}else
			{	if(vars[i].getType() == "ARRAY"){
					symbolTable.insert(vars[i].getName(), "ARRAY_" + $1->getName(), vars[i].getSize());
				}
				else
					symbolTable.insert(vars[i].getName(), "ID_" + $1->getName());
			}
		}
	}

	if($1->getName() == "INT") $1->setName("int");
	if($1->getName() == "FLOAT") $1->setName("float");
	if($1->getName() == "VOID") $1->setName("void");
	std::string codeText($1->getName() + " "
						+$2->getName()
						+";");
	logCode(codeText, "var_declaration : type_specifier declaration_list SEMICOLON");
	$$ = new SymbolInfo(codeText, "");
}
;




type_specifier : INT 
{
	//done
	logCode("int","type_specifier : INT");
	$$ = new SymbolInfo("INT", "");
}


| FLOAT 
{
	//done
	logCode("float","type_specifier : FLOAT");
	$$ = new SymbolInfo("FLOAT", "");
}


| VOID 
{
	//done
	logCode("void","type_specifier : VOID");
	$$ = new SymbolInfo("VOID", "");
}
;




declaration_list : declaration_list COMMA ID 
{
	//done
	$1->pushParam(SymbolInfo($3->getName(), "ID"));
	std::string codeText($1->getName()
						+ "," 
						+$3->getName());

	logCode(codeText, "declaration_list : declaration_list COMMA ID");
	$1->setName(codeText);
	$$ = $1;
}


| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD 
{
	//done
	std::string codeText($1->getName()
						+","
						+$3->getName()
						+"["
						+$5->getName()
						+"]");
	$1->pushParam(SymbolInfo($3->getName(), "ARRAY", std::stoi($5->getName())));

	$1->setName(codeText);
	$$ = $1;
	logCode(codeText, "declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD");
}


| declaration_list COMMA ID LTHIRD CONST_FLOAT RTHIRD 
{
	//done
	std::string codeText($1->getName() 
						+","
						+$3->getName()
						+"["
						+$5->getName()
						+"]");
	// $1->pushParam(SymbolInfo($3->getName(), "ARRAY", std::stoi($5->getName())));

	$1->setName(codeText);
	$$ = $1;
	errorLog("Array size can not be float");
}
| declaration_list COMMA ID LTHIRD RTHIRD 
{
	//done
	std::string codeText($1->getName() 
						+","
						+$3->getName()
						+"[]");
	// $1->pushParam(SymbolInfo($3->getName(), "ARRAY", std::stoi($5->getName())));

	$1->setName(codeText);
	$$ = $1;
	errorLog("Array size undeclared");
}


| ID 
{
	//done
	std::vector<SymbolInfo> paramList;
	std::string codeText($1->getName());

	paramList.push_back(SymbolInfo($1->getName(), "ID"));
	logCode(codeText, "declaration_list : ID");
	$$ = new SymbolInfo(codeText, "", paramList);
}


| ID LTHIRD CONST_INT RTHIRD 
{
	//done
	std::vector<SymbolInfo> paramList;
	std::string codeText($1->getName()
						+"["
						+$3->getName()
						+"]");
	paramList.push_back(SymbolInfo($1->getName(), "ARRAY", std::stoi($3->getName())));

	logCode(codeText, "eclaration_list : ID LTHIRD CONST_INT RTHIRD");
	$$ = new SymbolInfo(codeText, "", paramList);
}
| ID LTHIRD CONST_FLOAT RTHIRD
{
	//done
	std::vector<SymbolInfo> paramList;
	std::string codeText($1->getName()
						+"["
						+$3->getName()
						+"]");
	// paramList.push_back(SymbolInfo($1->getName(), "ARRAY", std::stoi($3->getName())));

	errorLog("Array size can not be float");
	$$ = new SymbolInfo(codeText, "", paramList);
}
| ID LTHIRD RTHIRD
{
	//done
	std::vector<SymbolInfo> paramList;
	std::string codeText($1->getName()
						+"[]");
	// paramList.push_back(SymbolInfo($1->getName(), "ARRAY", std::stoi($3->getName())));

	errorLog("Array size undeclared");
	$$ = new SymbolInfo(codeText, "", paramList);
}
;




statements : statement 
{
	//done
	std::string codeText(indentGen() + $1->getName());
	logCode(codeText, "statements : statement");
	$$ = new SymbolInfo(codeText, "");
}
| statements statement 
{
	//done
	std::string codeText($1->getName() + "\n" + indentGen() 
						+$2->getName());
	logCode(codeText, "statements : statements statement");
	$$ = new SymbolInfo(codeText, "");
}
|UNRECOGNIZED
{
	errorLog("Unrecognized Character");
	$$ = new SymbolInfo("", "VOID");
}
|error SEMICOLON
{
	$$ = new SymbolInfo("", "VOID");
}
|error LCURL
{
	$$ = new SymbolInfo("", "VOID");
}
;




statement : var_declaration 
{
	//done
	if(functionHasReturned)
	{
		warningLog("Statements after return is redundant.");
	}
	
	std::string codeText($1->getName() + "\n");
	logCode(codeText, "statement : var_declaration");
	$$ = new SymbolInfo(codeText, "");
}


| expression_statement 
{
	//done
	if(functionHasReturned)
	{
		warningLog("Statements after return is redundant.");
	}
	
	std::string codeText($1->getName());
	logCode(codeText, "statement : expression_statement");
	$$ = new SymbolInfo(codeText, "");
}

| {symbolTable.enterScope();tabSpace++;}
compound_statement 
{
	//done
	if(functionHasReturned)
	{
		warningLog("Statements after return is redundant.");
	}

	yacclogfile << "Scope #" << symbolTable.getCurrentScopeID() << " Exited" << std::endl;
	yacclogfile << symbolTable.printAllScopeTable() << std::endl << std::endl;
	symbolTable.exitScope();
	tabSpace--;
	
	std::string codeText($2->getName() + "\n");
	logCode(codeText, "statement : compound_statement");
	$$ = new SymbolInfo(codeText, "");
}


| FOR LPAREN expression_statement expression_statement expression RPAREN statement 
{
	//done
	if(functionHasReturned)
	{
		warningLog("Statements after return is redundant.");
	}
	
	std::string codeText("for ("
						+$3->getName()
						+$4->getName()
						+$5->getName() + ")"
						+$7->getName() + "\n");
	logCode(codeText, "statements : FOR LPAREN expression_statement expression_statement expression RPAREN statement");
	$$ = new SymbolInfo(codeText, "");
}


| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE 
{
	//done
	if(functionHasReturned)
	{
		warningLog("Statements after return is redundant.");
	}
	
	std::string codeText("if ("
						+$3->getName()
						+")"
						+$5->getName() + "\n");
	logCode(codeText, "statements : IF LPAREN expression RPAREN statement %%prec LOWER_THAN_ELSE");
	$$ = new SymbolInfo(codeText, "");
}


| IF LPAREN expression RPAREN statement ELSE statement 
{
	//done
	if(functionHasReturned)
	{
		warningLog("Statements after return is redundant.");
	}
	
	std::string codeText("if ("
						+$3->getName()
						+")"
						+$5->getName()
						+ indentGen() + "else "
						+$7->getName() + "\n");
	logCode(codeText, "statements : IF LPAREN expression RPAREN statement ELSE statement");
	$$ = new SymbolInfo(codeText, "");
}


| WHILE LPAREN expression RPAREN statement 
{
	//done
	if(functionHasReturned)
	{
		warningLog("Statements after return is redundant.");
	}

	std::string codeText("while ("
						+$3->getName()
						+")\n"
						+$5->getName() + "\n");
	logCode(codeText, "statements : WHILE LPAREN expression RPAREN statement");
	$$ = new SymbolInfo(codeText, "");
}


| PRINTLN LPAREN ID RPAREN SEMICOLON 
{
	//done
	if(functionHasReturned)
	{
		warningLog("Statements after return is redundant.");
	}

	SymbolInfo* scopeId = symbolTable.lookup($3->getName());
	if(scopeId == nullptr){
		errorLog("Undeclared variable " + $3->getName());
	}else if(isFunction(scopeId->getType())){
		errorLog($3->getName() + " declared as function");
	}

	std::string codeText("printf("
						+$3->getName()
						+");\n");
	logCode(codeText, "statements : PRINTLN LPAREN ID RPAREN SEMICOLON");
	$$ = new SymbolInfo(codeText, "");	
}


| RETURN expression SEMICOLON 
{
	//done
	if(functionHasReturned)
	{
		warningLog("Statements after return is redundant.");
	}
	else
	{
		if(currentReturnType == "VOID")
		{
			errorLog("Void type function can't return value.");
		}
		else
		{
			if(currentReturnType != $2->getType())
			{
				errorLog("Return type mismatch with function declaration in function" + currentFunction);
			}
			else
			{
				//function returned
				functionHasReturned = true;
			}
		}
	}
	std::string codeText("return "
						+$2->getName()
						+";");
	logCode(codeText, "statement : RETURN expression SEMICOLON");
	$$ = new SymbolInfo(codeText, "");	
}
;


expression_statement: SEMICOLON 
{
	//done
	std::string codeText(";");
	logCode(codeText, "expression_statement: SEMICOLON");
	$$ = new SymbolInfo(codeText, "VOID");
}


| expression SEMICOLON 
{
	//done
	std::string codeText($1->getName() + ";");
	logCode(codeText, "expression_statement : expression SEMICOLON");
	$$ = new SymbolInfo(codeText, $1->getType());
}
;




variable : ID 
{
	//done
	std::string codeText($1->getName());
	std::string returnType = "VOID";

	SymbolInfo* closestScopeSymbol =
	symbolTable.lookup($1->getName());

	if(closestScopeSymbol == nullptr){
		errorLog("Undeclared variable " + $1->getName());
	}else{
		if(isArray(closestScopeSymbol->getType())){
			errorLog("Type mismatch, " + $1->getName() + " is an " + vartypeReturn(closestScopeSymbol->getType()));
		}else{
			returnType = typeReturn(closestScopeSymbol->getType());
		}
	}

	logCode(codeText, "variable : ID");
	$$ = new SymbolInfo(codeText, returnType);
}
| ID LTHIRD expression RTHIRD 
{
	//done
	std::string codeText($1->getName() + "[" 
						+ $3->getName() + "]");
	std::string returnType = "VOID";
	
	SymbolInfo* closestScopeSymbol =
	symbolTable.lookup($1->getName());



	if(closestScopeSymbol == nullptr){
		errorLog("Undeclared variable " + $1->getName());
	}else{
		if(!isArray(closestScopeSymbol->getType())){
			errorLog($1->getName() + " is not an array");
		}else{
			if($3->getType() == "VOID" || $3->getType() == "FLOAT"){
				errorLog("Expression inside third brackets not an integer");
			}else{
				returnType = typeReturn(closestScopeSymbol->getType());
			}
		}
	}

	logCode(codeText, "variable : ID LTHIRD expression RTHIRD");
	$$ = new SymbolInfo(codeText, returnType);
}
;




expression : logic_expression 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "expression : logic_expression");
	$$ = new SymbolInfo(codeText, $1->getType());
}


| variable ASSIGNOP logic_expression 
{
	//done
	std::string returnType("VOID");
	if($1->getType() == "VOID"){
		//invalid operation
		//errorLog("Invalid l-value, cannot assign value");
	}else if($3->getType() == "VOID"){
		//invalid operation
		//errorLog("Invalid r-value, cannot evaluate expression");
	}else if($3->getType() == "VOID_FUNC"){
		errorLog("Void function used in expression");
	}else if($1->getType() != $3->getType()){
		if($1->getType() == "INT"){
			errorLog("Type Mismatch");
			returnType = "INT";
		}else{
			warningLog("Converting integer value to float");
			returnType = "FLOAT";
		}
	}else{
		//successful code
		returnType = $1->getType();
	}
	std::string codeText($1->getName() + "="
						+$3->getName());
	logCode(codeText, "expression : variable ASSIGNOP logic_expression");
	$$ = new SymbolInfo(codeText, returnType);
}
;




logic_expression : rel_expression 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "logic_expression : rel_expression");
	$$ = new SymbolInfo(codeText, $1->getType());
}


| rel_expression LOGICOP rel_expression 
{
	//done
	std::string returnType("VOID");
	if($1->getType() != "INT" || $3->getType() != "INT"){
		//invalid operation
		//errorLog("Invalid datatypes for logical operation, needs to be integers.");
	}else if($1->getType() == "VOID_FUNC" || $3->getType() == "VOID_FUNC"){
		errorLog("Void function used in expression");
	}else{
		//successful code
		returnType = "INT";
	}
	std::string codeText($1->getName()
						+$2->getName()
						+$3->getName());
	logCode(codeText, "logic_expression : rel_expression LOGICOP rel_expression");
	$$ = new SymbolInfo(codeText, returnType);

}
;




rel_expression : simple_expression 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "rel_expression : simple_expression");
	$$ = new SymbolInfo(codeText, $1->getType());
}


| simple_expression RELOP simple_expression
{
	//done
	std::string returnType("VOID");
	if($1->getType() == "VOID" || $3->getType() == "VOID"){
		//invalid operation
		//errorLog("Invalid operation");
	}else if($1->getType() == "VOID_FUNC" || $3->getType() == "VOID_FUNC"){
		errorLog("Void function used in expression");
	}else if($1->getType() != $3->getType()){
		warningLog("Type mismatch, may result incorrect behaviour");
		returnType = "INT";
	}else{
		//successful code 
		//result of relop is always either 0 or 1, integer
		returnType = "INT";
	}
	std::string codeText($1->getName()
						+$2->getName()
						+$3->getName());
	logCode(codeText, "rel_expression : simple_expression RELOP simple_expression");
	$$ = new SymbolInfo(codeText, returnType);
}
;




simple_expression : term 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "simple_expression : term");
	$$ = new SymbolInfo(codeText, $1->getType());	
}


| simple_expression ADDOP term 
{
	//done
	std::string returnType("VOID");
	if($1->getType() == "VOID" || $3->getType() == "VOID"){
		//invalid operation
		//errorLog("Invalid operation.");
	}else if($1->getType() == "VOID_FUNC"){
		errorLog("Void function used in expression");
	}else if($1->getType() != $3->getType()){
		warningLog("Converting integer to float.");
		returnType = "FLOAT";
	}else{
		//successful code
		returnType = $1->getType();
	}
	std::string codeText($1->getName() 
						+$2->getName()
						+$3->getName());
	logCode(codeText, "simple_expression : simple_expression ADDOP term");
	$$ = new SymbolInfo(codeText, returnType);
}
;




term : unary_expression 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "term : unary_expression");
	$$ = new SymbolInfo(codeText, $1->getType());
}


| term MULOP unary_expression 
{
	//done
	std::string returnType("VOID");
	if($1->getType() == "VOID" || $3->getType() == "VOID"){
		//invalid operation
		//errorLog("Invalid operation.");
	}else if($3->getName() == "0"){
		if($2->getName() == "/"){
			errorLog("Divide by Zero");
		}else if($2->getName() == "%"){
			errorLog("Modulus by Zero");
		}
	}else if($3->getType() == "VOID_FUNC"){
		errorLog("Void function used in expression");
	}else if($2->getName() == "%" && ($1->getType() != "INT" || $3->getType() != "INT")){
		errorLog("Non-Integer operand on modulus operator");
	}else if($1->getType() != $3->getType()){
		warningLog("Converting integer to float.");
		returnType = "FLOAT";
	}else{
		//successful code
		returnType = $1->getType();
	}
	std::string codeText($1->getName()
						+$2->getName()
						+$3->getName());
	logCode(codeText, "term : term MULOP unary_expression");
	$$ = new SymbolInfo(codeText, returnType);
}
;




unary_expression : ADDOP unary_expression 
{
	//done
	std::string codeText($1->getName() + $2->getName());
	if($2->getType() == "VOID"){
		//errorLog("Invalid operation.");
		//invalid operation
	}else if($2->getType() == "VOID_FUNC"){
		errorLog("Void function used in expression");
		$2->setType("VOID");
	}
	logCode(codeText, "unary_expression : ADDOP unary_expression ");
	$$ = new SymbolInfo(codeText, $2->getType());
}


| NOT unary_expression 
{
	//done
	std::string returnType("VOID");
	std::string codeText("!" + $2->getName());
	if($2->getType() == "VOID"){
		//errorLog("Invalid operation.");
		//invalid operation
	}else if($2->getType() == "VOID_FUNC"){
		errorLog("Void function used in expression");
	}else if($2->getType() == "FLOAT"){
		errorLog("Invalid datatypes for logical operation, needs to be integers.");
	}else{
		returnType = "INT";
	}
	logCode(codeText, "unary_expression : NOT unary_expression");
	$$ = new SymbolInfo(codeText, returnType);
}


| factor 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "unary_expression : factor");
	$$ = new SymbolInfo(codeText, $1->getType());
}
;




factor : variable 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "factor : variable");
	$$ = new SymbolInfo(codeText, $1->getType());
}


| ID LPAREN argument_list RPAREN 
{
	//done
	SymbolInfo* 
	globalAvailability = symbolTable.lookGlobalScope($1->getName());

	bool allOk = true;

	if(globalAvailability == nullptr){
		errorLog("Undeclared function " + $1->getName());
		allOk = false;
	}else if(!isFunction(globalAvailability->getType())){
		errorLog($1->getName() + " is not a function.");
		allOk = false;
	}else{
		std::vector<SymbolInfo> params = globalAvailability->getParamList();
		std::vector<SymbolInfo> args = $3->getParamList();

		for(int i = 0; i < args.size(); i++){
			if(args[i].getType() == "VOID"){
				allOk = false;
			}else if(args[i].getType() == "VOID_FUNC"){
				errorLog("Void function used in expression");
				allOk = false;
			}
		}
		if(allOk){
			if(params.size() != args.size()){
				errorLog("Total number of arguments mismatch with declaration in function " + $1->getName());
				allOk = false;
			}else{
				for(int i = 0; i < args.size(); i++){
					if(args[i].getType() != typeReturn(params[i].getType())){
						errorLog(std::to_string(i + 1) + "th argument mismatch in function " + $1->getName());
						allOk = false;
						break;
					}
				}
			}
		}
	}
	std::string codeText($1->getName()
						+"("
						+$3->getName()
						+")");
	if(globalAvailability != nullptr && globalAvailability->getType() == "FUNC_VOID"){
		$$ = new SymbolInfo(codeText, "VOID_FUNC");
	}else if(allOk){
		$$ = new SymbolInfo(codeText, typeReturn(globalAvailability->getType()));
	}else{
		$$ = new SymbolInfo(codeText, "VOID");
	}
	logCode(codeText, "factor : ID LPAREN argument_list RPAREN");
}


| LPAREN expression RPAREN 
{
	//done
	std::string codeText("(" + $2->getName() + ")");
	logCode(codeText, "factor : LPAREN expression RPAREN");
	$$ = new SymbolInfo(codeText, $2->getType());
}


| CONST_INT 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "factor : CONST_INT");
	$$ = new SymbolInfo(codeText, "INT");
}


| CONST_FLOAT 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "factor : CONST_FLOAT");
	$$ = new SymbolInfo(codeText, "FLOAT");
}


| variable INCOP 
{
	//done
	std::string returnType("VOID");
	std::string codeText($1->getName() + "++");
	if($1->getType() == "VOID"){
		errorLog("Invalid operation.");
	}else{
		returnType = $1->getType();
	}
	logCode(codeText, "factor : variable INCOP");
	$$ = new SymbolInfo(codeText, returnType);
}


| variable DECOP 
{
	//done
	std::string returnType("VOID");
	std::string codeText($1->getName() + "--");
	if($1->getType() == "VOID"){
		errorLog("Invalid operation.");
	}else{
		returnType = $1->getType();
	}
	logCode(codeText, "factor : variable DECOP");
	$$ = new SymbolInfo(codeText, returnType);
}
;




argument_list :	arguments 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "argument_list : arguments");
	$1->setName(codeText);
	$$ = $1;
}


| 
{
	//done
	std::string codeText("");
	logCode(codeText, "argument_list : ");
	$$ = new SymbolInfo(codeText, "");
}
;




arguments : arguments COMMA logic_expression 
{
	$1->pushParam(SymbolInfo("", $3->getType()));
	std::string codeText($1->getName()
						+ ","
						+$3->getName());

	logCode(codeText, "arguments : arguments COMMA logic_expression");
	$1->setName(codeText);
	$$ = $1;
}
| logic_expression 
{
	std::vector<SymbolInfo> paramList;
	std::string codeText($1->getName());

	paramList.push_back(SymbolInfo("", $1->getType()));
	logCode(codeText, "arguments : logic_expression");
	$$ = new SymbolInfo(codeText, "", paramList);
}
;

%%

int main(int argc,char *argv[])
{
    inputFile = fopen(argv[1], "r");

	if(inputFile == nullptr) {
		printf("Cannot Open Input File.\n");
		exit(1);
	}

    lexlogfile.open("1805055_lex_log.txt");
    lextokenfile.open("1805055_lex_token.txt");

    yacclogfile.open("1805055_yacc_log.txt");
    errorFile.open("1805055_yacc_error.txt");

    yyin = inputFile;
    yyparse();

	lexlogfile << "\nLine count: " << lineCount << std::endl;
	lexlogfile << "Error count: " << lexErrorCount << std::endl;

	yacclogfile << "\nLine count: " << lineCount << std::endl;
	yacclogfile << "Error count: " << yaccErrorCount << std::endl;
	yacclogfile << "Warning count: " << yaccWarningCount << std::endl;

	lexlogfile.close();
	lextokenfile.close();
	yacclogfile.close();
	errorFile.close();

    return 0;    
}