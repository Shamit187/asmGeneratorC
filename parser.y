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
	formattedCode << codeText << std::endl;
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
			symbolTable.insert($2->getName(), "FUNC_" + $1->getName(), vars, newFuncGenerator($2->getName()));
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
		symbolTable.insert($2->getName(), "FUNC_" + $1->getName(), newFuncGenerator($2->getName()));
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
							symbolTable.insert($2->getName(), "FUNC_" + $1->getName(), defn, newFuncGenerator($2->getName()));
						}
						insertParameterFlag = true; // should not include parameters to symboltable here, must do it after entering a new scope
						symbolTable.define($2->getName());
					}
				}
			}
		}
	}
	symbolTable.enterScope();
	offsetStack.push(0);
	tabSpace++;
	for(int i = 0; i < defn.size(); i++){
		std::string asmCode = "[BP + " + std::to_string(2*(i+2)) + " ]";
		if(!symbolTable.insert(defn[i].getName(), defn[i].getType(), asmCode)) errorLog("Multiple declaration of " + defn[i].getName() + " in parameter");
	}
	//code logs are included in next part

	globalAvailability = symbolTable.lookGlobalScope($2->getName());

	if(globalAvailability != nullptr){
		//asm code
		if(currentFunction == "main"){
			std::string convertedCode = "MAIN PROC\n";
			std::string comment = "main function initialization";

			writeToAsm(convertedCode, comment, false);

			convertedCode = "MOV AX, @DATA\nMOV DS, AX\n";
			comment = "data initialization";

			writeToAsm(convertedCode, comment, true);
		}else{
			currentAsmFunction = globalAvailability->getAsm();
			std::string convertedCode = currentAsmFunction + " PROC\n";
			std::string comment = currentFunction + " function initialization";

			writeToAsm(convertedCode, comment, false);
		}	
		std::string convertedCode = "PUSH BP\nMOV BP, SP";
		std::string comment = "function stack movement for recursive calling";
		writeToAsm(convertedCode, comment, true);

		currentOffset = 0;
	}
} 
compound_statement 
{
	if(!functionHasReturned && currentReturnType != "VOID"){
		errorLog("Function didn't return any value " + $2->getName());
	}

	yacclogfile << "Scope #" << symbolTable.getCurrentScopeID() << " Exited" << std::endl;
	yacclogfile << symbolTable.printAllScopeTable() << std::endl << std::endl;
	symbolTable.exitScope();

	//asm code
	std::string comment = "removing all variable in the scope";
	std::string convertedCode = "ADD SP, " + std::to_string(offsetStack.top()*2) + "\n";
	writeToAsm(convertedCode, comment, true);

	offsetStack.pop();
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

	//asm code
	convertedCode = "POP BP";
	comment = "stack movement for recursive calling, [if return available then it is in DX]";
	writeToAsm(convertedCode, comment, true);

	if(currentFunction == "main") {
		std::string convertedCode = "MOV AH,4CH\nINT 21h\n";
		std::string comment = "interrupt to return to operator";
		writeToAsm(convertedCode, comment, true);

		convertedCode = "MAIN ENDP\nEND MAIN\n";
		comment = "main function ending";
		writeToAsm(convertedCode, comment, false);
	}else{
		std::string convertedCode = "RET\n" + currentAsmFunction + " ENDP\n";
		std::string comment = currentFunction + " function ending";
		writeToAsm(convertedCode, comment, false);
	}
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
						symbolTable.insert($2->getName(), "FUNC_" + $1->getName(), newFuncGenerator($2->getName()));
					}
					symbolTable.define($2->getName());
				}
			}
		}
	}
	symbolTable.enterScope();
	offsetStack.push(0);
	tabSpace++;
	//code logs are included in next part
	globalAvailability = symbolTable.lookGlobalScope($2->getName());

	if(globalAvailability != nullptr){
		//asm code
		if(currentFunction == "main"){
			std::string convertedCode = "MAIN PROC\n";
			std::string comment = "main function initialization";

			writeToAsm(convertedCode, comment, false);

			convertedCode = "MOV AX, @DATA\nMOV DS, AX\n";
			comment = "data initialization";

			writeToAsm(convertedCode, comment, true);
		}else{
			currentAsmFunction = globalAvailability->getAsm();
			std::string convertedCode = currentAsmFunction + " PROC\n";
			std::string comment = currentFunction + " function initialization";

			writeToAsm(convertedCode, comment, false);
		}	
		std::string convertedCode = "PUSH BP\nMOV BP, SP";
		std::string comment = "function stack movement for recursive calling";
		writeToAsm(convertedCode, comment, true);

		currentOffset = 0;
	}
} 
compound_statement 
{
	if(!functionHasReturned && currentReturnType != "VOID"){
		errorLog("Function didn't return any value " + $2->getName());
	}

	yacclogfile << "Scope #" << symbolTable.getCurrentScopeID() << " Exited" << std::endl;
	yacclogfile << symbolTable.printAllScopeTable() << std::endl << std::endl;
	symbolTable.exitScope();

	//asm code
	std::string comment = "removing all variable in the scope";
	std::string convertedCode = "ADD SP, " + std::to_string(offsetStack.top()*2) + "\n";
	writeToAsm(convertedCode, comment, true);
	
	offsetStack.pop();
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

	//asm code
	convertedCode = "POP BP";
	comment = "stack movement for recursive calling, [if return available then it is in DX]";
	writeToAsm(convertedCode, comment, true);

	if(currentFunction == "main") {
		std::string convertedCode = "MOV AH,4CH\nINT 21h\n";
		std::string comment = "interrupt to return to operator";
		writeToAsm(convertedCode, comment, true);

		convertedCode = "MAIN ENDP\nEND MAIN\n";
		comment = "main function ending";
		writeToAsm(convertedCode, comment, false);
	}else{
		std::string convertedCode = "RET\n" + currentAsmFunction + " ENDP\n";
		std::string comment = currentFunction + " function ending";
		writeToAsm(convertedCode, comment, false);
	}
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
	$$ = new SymbolInfo(codeText, "", paramList, "");
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
	$$ = new SymbolInfo(codeText, "", paramList,"");
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
					//asm code
					std::string comment = "array declaration " + vars[i].getName() + " of size " + std::to_string(vars[i].getSize());
					std::string asmCode;
					bool local = true;

					if(symbolTable.getCurrentScopeID().size() == 1){
						//global arr
						asmCode = newVarGenerator(vars[i].getName());

						symbolTable.insert(vars[i].getName(), "ARRAY_" + $1->getName(), vars[i].getSize(), asmCode);
						asmCode += " DW " + std::to_string(vars[i].getSize()) + " DUP(?)\n";
						local = false;
					}else{
						//regular arr
						asmCode = "[BP - " + std::to_string((currentOffset + 1 )*2) + "]";
						currentOffset += vars[i].getSize();
						int temp = offsetStack.top(); offsetStack.pop();
						offsetStack.push(temp + vars[i].getSize());

						symbolTable.insert(vars[i].getName(), "ARRAY_" + $1->getName(), vars[i].getSize(), asmCode);
						asmCode = "SUB SP, " + std::to_string(vars[i].getSize() * 2) + "\n";
					}
					writeToAsm(asmCode, comment, local);
				}
				else{
					//asm code
					std::string comment = "var declaration " + vars[i].getName();
					std::string asmCode;
					bool local = true;

					if(symbolTable.getCurrentScopeID().size() == 1){ 
						//global vars
						asmCode = newVarGenerator(vars[i].getName());

						symbolTable.insert(vars[i].getName(), "ID_" + $1->getName(), asmCode);
						asmCode += " DW ?\n";
						local = false;
					}else{ 
						//regular vars
						currentOffset++;
						asmCode = "[BP - " + std::to_string(currentOffset*2) + "]";
						int temp = offsetStack.top(); offsetStack.pop();
						offsetStack.push(temp + 1);

						symbolTable.insert(vars[i].getName(), "ID_" + $1->getName(), asmCode);
						asmCode = "SUB SP, 2\n";
					}
					writeToAsm(asmCode, comment, local);
				}
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
	$1->pushParam(SymbolInfo($3->getName(), "ARRAY", std::stoi($5->getName()), ""));

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
	$$ = new SymbolInfo(codeText, "", paramList, "");
}


| ID LTHIRD CONST_INT RTHIRD 
{
	//done
	std::vector<SymbolInfo> paramList;
	std::string codeText($1->getName()
						+"["
						+$3->getName()
						+"]");
	paramList.push_back(SymbolInfo($1->getName(), "ARRAY", std::stoi($3->getName()), " "));

	logCode(codeText, "eclaration_list : ID LTHIRD CONST_INT RTHIRD");
	$$ = new SymbolInfo(codeText, "", paramList, "");
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
	$$ = new SymbolInfo(codeText, "", paramList, "");
}
| ID LTHIRD RTHIRD
{
	//done
	std::vector<SymbolInfo> paramList;
	std::string codeText($1->getName()
						+"[]");
	// paramList.push_back(SymbolInfo($1->getName(), "ARRAY", std::stoi($3->getName())));

	errorLog("Array size undeclared");
	$$ = new SymbolInfo(codeText, "", paramList, "");
}
;




statements : statement 
{
	//done
	std::string codeText(indentGen() + $1->getName());
	logCode(codeText, "statements : statement");
	$$ = new SymbolInfo(codeText, "");

	//asm code
	currentOffset -= tempOffset;
	int temp = offsetStack.top(); offsetStack.pop();
	offsetStack.push(temp - tempOffset);
	std::string comment = "removing temp vars of the expressions";
	std::string compiledCode = "ADD SP, " + std::to_string(tempOffset * 2) + "\n";
	tempOffset = 0;
	writeToAsm(compiledCode, comment, true);
}
| statements statement 
{
	//done
	std::string codeText($1->getName() + "\n" + indentGen() 
						+$2->getName());
	logCode(codeText, "statements : statements statement");
	$$ = new SymbolInfo(codeText, "");

	//asm code
	currentOffset -= tempOffset;
	int temp = offsetStack.top(); offsetStack.pop();
	offsetStack.push(temp - tempOffset);
	std::string comment = "removing temp vars of the expressions";
	std::string compiledCode = "ADD SP, " + std::to_string(tempOffset * 2) + "\n";
	tempOffset = 0;
	writeToAsm(compiledCode, comment, true);
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

| {symbolTable.enterScope();offsetStack.push(0);tabSpace++;}
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
	asmFile << "ADD SP, " + std::to_string(offsetStack.top()*2) + "\n";
	offsetStack.pop();
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

	//asm code
	std::string comment = "printf(" + scopeId->getName() + ")";
	std::string asmCode = "MOV AX, " + scopeId->getAsm() + "\nCALL PRINT\n";
	writeToAsm(asmCode, comment, true);
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
	std::string asmCode = "";

	SymbolInfo* closestScopeSymbol =
	symbolTable.lookup($1->getName());

	if(closestScopeSymbol == nullptr){
		errorLog("Undeclared variable " + $1->getName());
	}else{
		if(isArray(closestScopeSymbol->getType())){
			errorLog("Type mismatch, " + $1->getName() + " is an " + vartypeReturn(closestScopeSymbol->getType()));
		}else{
			returnType = typeReturn(closestScopeSymbol->getType());

			//asm code
			asmCode = closestScopeSymbol->getAsm();
		}
	}

	logCode(codeText, "variable : ID");
	$$ = new SymbolInfo(codeText, returnType, asmCode);
}
| ID LTHIRD expression RTHIRD 
{
	//done
	std::string codeText($1->getName() + "[" 
						+ $3->getName() + "]");
	std::string returnType = "VOID";
	std::string asmCode;
	std::string address;
	
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

				//asm code
				std::string comment = "array[expression].. i hate this code..";

				std::string compiledCode = "MOV AX, " + $3->getAsm() + "\n";
				compiledCode += "MOV BX, BP\n";
				compiledCode += "SUB BX, " + getOffset(closestScopeSymbol->getAsm()) + "\n";
				compiledCode += "SHL AX, 1\n";
				compiledCode += "SUB BX, AX\n";
				
				//new temp()
				currentOffset++;
				tempOffset++;
				asmCode = "[BP - " + std::to_string(currentOffset*2) + "]";
				int temp = offsetStack.top(); offsetStack.pop();
				offsetStack.push(temp + 1);

				//symbolTable.insert(newTemp(), "ID_INT", asmCode);
				compiledCode += "PUSH [BX]\n";

				//new Temp()
				currentOffset++;
				tempOffset++;
				address = "[BP - " + std::to_string(currentOffset*2) + "]";
				temp = offsetStack.top(); offsetStack.pop();
				offsetStack.push(temp + 1);

				//symbolTable.insert(newTemp(), "ID_INT", asmCode);
				compiledCode += "PUSH BX\n";

				writeToAsm(compiledCode, comment, true);
			}
		}
	}

	logCode(codeText, "variable : ID LTHIRD expression RTHIRD");
	$$ = new SymbolInfo(codeText, returnType, asmCode);
	$$->setAddress(address);
}
;




expression : logic_expression 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "expression : logic_expression");
	$$ = new SymbolInfo(codeText, $1->getType(), $1->getAsm());
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

		//asm code
		std::string comment =$1->getName() + "="
							+$3->getName();
		std::string compiledCode = "";
		compiledCode += "MOV AX, " + $3->getAsm() + "\n";

		if($1->hasAddress()){
			compiledCode += "MOV " + $1->getAddress() + ", BX\n";
			compiledCode += "MOV [BX], AX\n";
		}else{
			compiledCode += "MOV " + $1->getAsm() + ", AX\n";
		}
		
		writeToAsm(compiledCode, comment, true);
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
	$$ = new SymbolInfo(codeText, $1->getType(), $1->getAsm());
}


| rel_expression LOGICOP
{
	std::string compiledCode = "";
	std::string label =  newLabel(); //pass via logic op address
	std::string asmCode; //pass via logic op asm code

	currentOffset++;
	tempOffset++;
	asmCode = "[BP - " + std::to_string(currentOffset*2) + "]";
	int temp = offsetStack.top(); offsetStack.pop();
	offsetStack.push(temp + 1);

	compiledCode += "SUB SP, 2\n";

	//asm code
	if($2->getName() == "&&"){
		compiledCode += "MOV AX, " + $1->getAsm() + "\n";
		compiledCode += "MOV " + asmCode + ", AX\n"; 
		compiledCode += "CMP " + $1->getAsm() + ", 0\n";
		compiledCode += "JE " + label + "\n";
	}else{
		compiledCode += "MOV AX, " + $1->getAsm() + "\n";
		compiledCode += "MOV " + asmCode + ", AX\n"; 
		compiledCode += "CMP " + $1->getAsm() + ", 0\n";
		compiledCode += "JNE " + label + "\n";
	}

	writeToAsm(compiledCode, "short circuit start: " + $1->getName() + " " + $2->getName(), true);

	$2->setAsm(asmCode);
	$2->setAddress(label);

} rel_expression 
{
	//done
	std::string returnType("VOID");
	if($1->getType() != "INT" || $4->getType() != "INT"){
		//invalid operation
		//errorLog("Invalid datatypes for logical operation, needs to be integers.");
	}else if($1->getType() == "VOID_FUNC" || $4->getType() == "VOID_FUNC"){
		errorLog("Void function used in expression");
	}else{
		//successful code
		returnType = "INT";
	}
	std::string codeText($1->getName()
						+$2->getName()
						+$4->getName());


	//asm code
	std::string compiledCode = "";
	compiledCode += "MOV AX, " + $4->getAsm() + "\n";
	compiledCode += "MOV " + $2->getAsm() + ", AX\n"; 
	compiledCode += $2->getAddress() + ":\n";

	writeToAsm(compiledCode, "short circuit end: " + $2->getName() + " " + $4->getName(), true);

	logCode(codeText, "logic_expression : rel_expression LOGICOP rel_expression");
	$$ = new SymbolInfo(codeText, returnType, $2->getAsm());

}
;




rel_expression : simple_expression 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "rel_expression : simple_expression");
	$$ = new SymbolInfo(codeText, $1->getType(), $1->getAsm());
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
	$$ = new SymbolInfo(codeText, $1->getType(), $1->getAsm());	
}


| simple_expression ADDOP term 
{
	//done
	std::string asmCode;
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

		//asm code
		currentOffset++;
		tempOffset++;
		asmCode = "[BP - " + std::to_string(currentOffset*2) + "]";
		int temp = offsetStack.top(); offsetStack.pop();
		offsetStack.push(temp + 1);

		//symbolTable.insert(newTemp(), "ID_INT", asmCode);

		std::string comment =$1->getName() 
							+$2->getName()
							+$3->getName();
		std::string compiledCode = "SUB SP, 2\n";
		compiledCode += "MOV AX, " + $1->getAsm() + "\n";
		if($2->getName() == "+")
			compiledCode += "ADD AX, " + $3->getAsm() + "\n";
		else
			compiledCode += "SUB AX, " + $3->getAsm() + "\n";
		compiledCode += "MOV " + asmCode + ", AX\n";

		writeToAsm(compiledCode, comment, true);

	}
	std::string codeText($1->getName() 
						+$2->getName()
						+$3->getName());
	logCode(codeText, "simple_expression : simple_expression ADDOP term");
	$$ = new SymbolInfo(codeText, returnType, asmCode);
}
;




term : unary_expression 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "term : unary_expression");
	$$ = new SymbolInfo(codeText, $1->getType(), $1->getAsm());
}


| term MULOP unary_expression 
{
	//done
	std::string returnType("VOID");
	std::string asmCode;
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

		//asm code
		currentOffset++;
		tempOffset++;
		asmCode = "[BP - " + std::to_string(currentOffset*2) + "]";
		int temp = offsetStack.top(); offsetStack.pop();
		offsetStack.push(temp + 1);

		//symbolTable.insert(newTemp(), "ID_INT", asmCode);
		std::string comment =$1->getName() 
							+$2->getName()
							+$3->getName();
		std::string compiledCode = "SUB SP, 2\n";
		compiledCode += "MOV AX, " + $1->getAsm() + "\n";
		compiledCode += "MOV BX, " + $3->getAsm() + "\n";
		if($2->getName() == "*"){
			//multiplication
			compiledCode += "MUL BX\n";
			compiledCode += "MOV " + asmCode + ", AX\n";	
		}else if($2->getName() == "/"){
			//division
			compiledCode += "XOR DX, DX\n";
			compiledCode += "DIV BX\n";
			compiledCode += "MOV " + asmCode + ", AX\n";
		}else{
			//modulus
			compiledCode += "XOR DX, DX\n";
			compiledCode += "DIV BX\n";
			compiledCode += "MOV " + asmCode + ", DX\n";
		}
		writeToAsm(compiledCode, comment, true);

	}
	std::string codeText($1->getName()
						+$2->getName()
						+$3->getName());
	logCode(codeText, "term : term MULOP unary_expression");
	$$ = new SymbolInfo(codeText, returnType, asmCode);
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
	}else{
		//asm code
		if($1->getName() == "-"){
			std::string comment = codeText;
			std::string compiledCode = "MOV  AX, " + $2->getAsm() + "\n";
			compiledCode += "NEG AX\n";
			compiledCode += "MOV " + $2->getAsm() + ", AX\n";

			writeToAsm(compiledCode, comment, true);
		}
	}
	logCode(codeText, "unary_expression : ADDOP unary_expression ");
	$$ = new SymbolInfo(codeText, $2->getType(), $2->getAsm());
}


| NOT unary_expression 
{
	//done
	std::string returnType("VOID");
	std::string codeText("!" + $2->getName());
	std::string asmCode;
	if($2->getType() == "VOID"){
		//errorLog("Invalid operation.");
		//invalid operation
	}else if($2->getType() == "VOID_FUNC"){
		errorLog("Void function used in expression");
	}else if($2->getType() == "FLOAT"){
		errorLog("Invalid datatypes for logical operation, needs to be integers.");
	}else{
		returnType = "INT";

		//asm code
		std::string comment = codeText;
		std::string label1 = newLabel();
		std::string label2 = newLabel();

		currentOffset++;
		tempOffset++;
		asmCode = "[BP - " + std::to_string(currentOffset*2) + "]";
		int temp = offsetStack.top(); offsetStack.pop();
		offsetStack.push(temp + 1);

		//symbolTable.insert(newTemp(), "ID_INT", asmCode);

		std::string compiledCode = "SUB SP, 2\n";
		compiledCode+= 	"MOV AX, " + $2->getAsm() + "\n";
		compiledCode+= 	"MOV " + asmCode  + ", AX\n";
		compiledCode+= 	"MOV AX, 0000H\n";
		compiledCode+= 	"MOV BX, 0001H\n";
		compiledCode+= 	"CMP " + asmCode + ", AX\n";
		compiledCode+=	"JE " + label1 + "\n";
		compiledCode+=	"MOV " + asmCode + ", AX\n";
		compiledCode+=	"JMP " + label2 + "\n";
		compiledCode+=	label1 + ":\n";  
		compiledCode+=	"MOV " + asmCode + ", BX\n";
		compiledCode+=	label2 + ":\n";

		writeToAsm(compiledCode, comment, true);
	}
	logCode(codeText, "unary_expression : NOT unary_expression");
	$$ = new SymbolInfo(codeText, returnType, asmCode);
}


| factor 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "unary_expression : factor");
	$$ = new SymbolInfo(codeText, $1->getType(), $1->getAsm());
}
;




factor : variable 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "factor : variable");
	$$ = new SymbolInfo(codeText, $1->getType(), $1->getAsm());
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

	if(globalAvailability != nullptr){

		//asm code
		std::vector<SymbolInfo> args = $3->getParamList();
		std::string comment = "the function call for " + globalAvailability->getName() + " ^_^ \n";

		std::string compiledCode = "";
		for(int i = 0; i < args.size(); i++){
			compiledCode += "PUSH " + args[i].getAsm() + "\n";
		}
		compiledCode += "CALL " + globalAvailability->getAsm() + "\n";
		for(int i = 0; i < args.size(); i++){
			compiledCode += "POP AX\n";
		}

		currentOffset++;
		tempOffset++;
		std::string asmCode = "[BP - " + std::to_string(currentOffset*2) + "]";
		int temp = offsetStack.top(); offsetStack.pop();
		offsetStack.push(temp + 1);

		//symbolTable.insert(newTemp(), "ID_INT", asmCode);
		compiledCode += "PUSH DX";
		writeToAsm(compiledCode, comment, true);

		$$->setAsm(asmCode);
	}


	logCode(codeText, "factor : ID LPAREN argument_list RPAREN");
}


| LPAREN expression RPAREN 
{
	//done
	std::string codeText("(" + $2->getName() + ")");
	logCode(codeText, "factor : LPAREN expression RPAREN");
	$$ = new SymbolInfo(codeText, $2->getType(), $2->getAsm());
}


| CONST_INT 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "factor : CONST_INT");

	//asmCode
	currentOffset++;
	tempOffset++;
	std::string asmCode = "[BP - " + std::to_string(currentOffset*2) + "]";
	int temp = offsetStack.top(); offsetStack.pop();
	offsetStack.push(temp + 1);

	//symbolTable.insert(newTemp(), "ID_INT", asmCode);
	std::string compiledCode = "PUSH " + $1->getName() + "\n";
	writeToAsm(compiledCode, "CONST_INT " + $1->getName(), true);

	$$ = new SymbolInfo(codeText, "INT", asmCode);
}


| CONST_FLOAT 
{
	//done
	std::string codeText($1->getName());
	logCode(codeText, "factor : CONST_FLOAT");
	$$ = new SymbolInfo(codeText, "FLOAT", $1->getName());
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

		//asm code
		std::string comment = codeText;
		std::string compiledCode = "ADD " + $1->getAsm() + ", 1\n";

		writeToAsm(compiledCode, comment, true);

	}
	logCode(codeText, "factor : variable INCOP");
	$$ = new SymbolInfo(codeText, returnType, $1->getAsm());
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

		//asm code
		std::string comment = codeText;
		std::string compiledCode = "SUB " + $1->getAsm() + ", 1\n";

		writeToAsm(compiledCode, comment, true);
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
	$1->pushParam(SymbolInfo("", $3->getType(), $3->getAsm()));
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

	paramList.push_back(SymbolInfo("", $1->getType(), $1->getAsm()));
	logCode(codeText, "arguments : logic_expression");
	$$ = new SymbolInfo(codeText, "", paramList, "");
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

	asmFile.open("1805055_asm_code.asm");
	initAsmCode();

	formattedCode.open("1805055_formatted_code.txt");

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
	asmFile.close();
	formattedCode.close();

    return 0;    
}