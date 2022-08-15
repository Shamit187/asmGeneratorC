%{
    #include "parser.h"
%}

%define parse.error verbose

%union {
	SymbolInfo* symbolInfo;
}

%token RETURN VOID FLOAT INT IF ELSE INCOP DECOP ASSIGNOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON PRINTLN UNRECOGNIZED
%token <symbolInfo> WHILE FOR

%token <symbolInfo> ID CONST_INT CONST_FLOAT ADDOP MULOP RELOP LOGICOP

%type <symbolInfo> start program unit var_declaration variable type_specifier declaration_list expression_statement func_declaration parameter_list func_definition compound_statement statements unary_expression factor statement arguments expression logic_expression simple_expression rel_expression term argument_list
%type <symbolInfo> if_declaration

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
{
	//done
	//no asm required
	yacclogfile << "Scope #" << symbolTable.getCurrentScopeID() << " Exited" << std::endl;
	yacclogfile << symbolTable.printAllScopeTable() << std::endl << std::endl;
	tabSpace--;

	std::string codeText($1->getName());
	logCode(codeText, "start : program");
	$$ = new SymbolInfo(codeText, "");
	formattedCode << codeText << std::endl;
	delete $1;

	writeToAsm(" ", "code finised", false);
};

program : program unit 
{
	//done
	//no asm required
	std::string codeText($1->getName() + "\n" +$2->getName());
	logCode(codeText, "program : program unit");
	$$ = new SymbolInfo(codeText, "");
	delete $1;
}
| unit
{
	//done
	//no asm required
	std::string codeText($1->getName());
	logCode(codeText, "program : unit");
	$$ = new SymbolInfo(codeText, "");
	delete $1;
};

unit : var_declaration 
{
	//done
	//no asm required
	std::string codeText($1->getName());
	logCode(codeText, "unit : var_declaration");
	$$ = new SymbolInfo(codeText, "");
	delete $1;
}
| func_declaration 
{
	//done
	//no asm required
	std::string codeText($1->getName());
	logCode(codeText, "unit : func_declaration");
	$$ = new SymbolInfo(codeText, "");
	delete $1;
}
| func_definition 
{
	//done
	//no asm required
	std::string codeText($1->getName());
	logCode(codeText, "unit : func_definition");
	$$ = new SymbolInfo(codeText, "");
	delete $1;
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
};	

func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON 
{
	//done
	//no asm required
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
	delete $1;
	delete $2;
	delete $4;
	
	
}
| type_specifier ID LPAREN RPAREN SEMICOLON 
{
	//done
	//no asm required
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
	delete $1;
	delete $2;



};

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

	//scope enter
	symbolTable.enterScope();
	offsetStack.push_back(0);
	tabSpace++;
	for(int i = 0; i < defn.size(); i++){
		std::string asmCode = "[BP + " + std::to_string(2*(i+2)) + "]";
		if(!symbolTable.insert(defn[i].getName(), defn[i].getType(), asmCode)) errorLog("Multiple declaration of " + defn[i].getName() + " in parameter");
	}

	globalAvailability = symbolTable.lookGlobalScope($2->getName());

	if(globalAvailability != nullptr){


		//asm code for function beginning
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

		offsetStack.clear();
		offsetStack.push_back(0);
	}
} 
compound_statement 
{

	//scope end
	yacclogfile << "Scope #" << symbolTable.getCurrentScopeID() << " Exited" << std::endl;
	yacclogfile << symbolTable.printAllScopeTable() << std::endl << std::endl;
	symbolTable.exitScope();

	tabSpace--;

	if($1->getName() == "INT") $1->setName("int");
	if($1->getName() == "FLOAT") $1->setName("float");
	if($1->getName() == "VOID") $1->setName("void");
	std::string codeText($1->getName() + " " + $2->getName() + "(" + $4->getName() + ")\n" + $7->getName());
	logCode(codeText, "func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement");
	$$ = new SymbolInfo(codeText, "");

	//asm code for function ending
	if(currentFunction == "main") {

		std::string comment = "return label of the function " + currentFunction;
		std::string convertedCode = "__main_return: \n";
		writeToAsm(convertedCode, comment, true);

		comment = "removing all variable in the scope and storing the return value";
		convertedCode = "MOV SP, BP\nPUSH DX\n";
		writeToAsm(convertedCode, comment, true);

		comment = "stack movement for recursive calling, [if return available then it is in DX]";
		convertedCode = "MOV SP, BP\nPOP BP\n";
		writeToAsm(convertedCode, comment, true);

		comment = "interrupt to return to operator";
		convertedCode = "MOV AH,4CH\nINT 21h\n";
		writeToAsm(convertedCode, comment, true);

		comment = "main function ending";
		convertedCode = "MAIN ENDP\nEND MAIN\n";
		writeToAsm(convertedCode, comment, false);

	}else{

		std::string comment = "return label of the function " + currentFunction;
		std::string convertedCode = "__" + currentAsmFunction + "_return:\n";
		writeToAsm(convertedCode, comment, true);

		comment = "removing all variable in the scope and storing the return value";
		convertedCode = "MOV SP, BP\nPUSH DX\n";
		writeToAsm(convertedCode, comment, true);

		comment = "stack movement for recursive calling, [if return available then it is in DX]";
		convertedCode = "MOV SP, BP\nPOP BP\n";
		convertedCode += "RET " + std::to_string(2 * ($4->getParamList()).size()) + "\n";
		writeToAsm(convertedCode, comment, true);

		comment = currentFunction + " function ending";
		convertedCode = currentAsmFunction + " ENDP\n";
		writeToAsm(convertedCode, comment, false);
	}

	offsetStack.clear();
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
	//enter scope
	symbolTable.enterScope();
	tabSpace++;
	
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

		offsetStack.clear();
		offsetStack.push_back(0);
	}
} 
compound_statement 
{
	yacclogfile << "Scope #" << symbolTable.getCurrentScopeID() << " Exited" << std::endl;
	yacclogfile << symbolTable.printAllScopeTable() << std::endl << std::endl;
	//scope exit
	symbolTable.exitScope();
	tabSpace--;

	if($1->getName() == "INT") $1->setName("int");
	if($1->getName() == "FLOAT") $1->setName("float");
	if($1->getName() == "VOID") $1->setName("void");
	std::string codeText($1->getName() + " " + $2->getName() + "()\n" + $6->getName());
	logCode(codeText, "func_definition : type_specifier ID LPAREN RPAREN compound_statement");
	$$ = new SymbolInfo(codeText, "");

	//asm code
	if(currentFunction == "main") {

		std::string comment = "return label of the function " + currentFunction;
		std::string convertedCode = "__main_return: \n";
		writeToAsm(convertedCode, comment, true);

		comment = "removing all variable in the scope and storing the return value";
		convertedCode = "MOV SP, BP\nPUSH DX\n";
		writeToAsm(convertedCode, comment, true);

		comment = "stack movement for recursive calling, [if return available then it is in DX]";
		convertedCode = "MOV SP, BP\nPOP BP\n";
		writeToAsm(convertedCode, comment, true);

		comment = "interrupt to return to operator";
		convertedCode = "MOV AH,4CH\nINT 21h\n";
		writeToAsm(convertedCode, comment, true);

		comment = "main function ending";
		convertedCode = "MAIN ENDP\nEND MAIN\n";
		writeToAsm(convertedCode, comment, false);

	}else{

		std::string comment = "return label of the function " + currentFunction;
		std::string convertedCode = "__" + currentAsmFunction + "_return:\n";
		writeToAsm(convertedCode, comment, true);

		comment = "removing all variable in the scope and storing the return value";
		convertedCode = "MOV SP, BP\nPUSH DX\n";
		writeToAsm(convertedCode, comment, true);

		comment = "stack movement for recursive calling, [if return available then it is in DX]";
		convertedCode = "MOV SP, BP\nPOP BP\n";
		writeToAsm(convertedCode, comment, true);

		comment = currentFunction + " function ending";
		convertedCode = currentAsmFunction + " ENDP\n";
		writeToAsm(convertedCode, comment, false);
	}
}
;


parameter_list : parameter_list COMMA type_specifier ID 
{
	//done
	//no asm requried
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
	//no asm requried
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
	//no asm requried
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
	//no asm requried
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
	//no asm requried
	tabSpace--;
	std::string codeText(indentGen() + "{\n" + $2->getName() + "\n" + indentGen() + "}");
	tabSpace++;
	logCode(codeText, "compound_statement : LCURL statements RCURL");
	$$ = new SymbolInfo(codeText, " ");
}
| LCURL RCURL 
{
	//done
	//no asm requried
	std::string codeText( "{}\n");
	logCode(codeText, "compound_statement : LCURL statements RCURL");
	$$ = new SymbolInfo(codeText, " ");
}
;

var_declaration : type_specifier declaration_list SEMICOLON 
{
	//done

	if($1->getName() == "INT") $1->setName("int");
	if($1->getName() == "FLOAT") $1->setName("float");
	if($1->getName() == "VOID") $1->setName("void");
	std::string codeText($1->getName() + " " +$2->getName() +";");
	logCode(codeText, "var_declaration : type_specifier declaration_list SEMICOLON");
	$$ = new SymbolInfo(codeText, "");
};

type_specifier : INT 
{
	//done
	//no asm required
	logCode("int","type_specifier : INT");
	$$ = new SymbolInfo("INT", "");
	dataType = "INT";
}
| FLOAT 
{
	//done
	//no asm required
	logCode("float","type_specifier : FLOAT");
	$$ = new SymbolInfo("FLOAT", "");
	dataType = "FLOAT";
}
| VOID 
{
	//done
	//no asm required
	logCode("void","type_specifier : VOID");
	$$ = new SymbolInfo("VOID", "");
	dataType = "VOID";
};

declaration_list : declaration_list COMMA ID 
{
	//done
	$1->pushParam(SymbolInfo($3->getName(), "ID"));
	std::string codeText($1->getName()+ "," +$3->getName());

	logCode(codeText, "declaration_list : declaration_list COMMA ID");
	$1->setName(codeText);
	$$ = $1;

	if(dataType == "VOID")
	{
		errorLog("Variable type cannot be void");
	}
	else
	{
		SymbolInfo* globalAvailability = symbolTable.lookGlobalScope($3->getName());
		if(	globalAvailability != nullptr && isFunction(globalAvailability->getType()) )
		{
			/* global function exist with same name */
			errorLog("Variable can't have the same name as function " + $3->getName());
		}else if(symbolTable.lookCurrentScope($3->getName()) != nullptr){
			errorLog("Multiple declaration of " + $3->getName());
		}else
		{	
			//asm code for var declaration
			std::string comment = "var declaration " + $3->getName();
			std::string asmCode;
			bool local = true;

			if(symbolTable.getCurrentScopeID().size() == 1){ 
				//global vars
				asmCode = newVarGenerator($3->getName());

				symbolTable.insert($3->getName(), "ID_" + dataType , asmCode);
				asmCode += " DW ?\n";
				local = false;
			}else{ 
				//regular vars
				offsetStack.back()++;
				asmCode = "[BP - " + std::to_string(offsetStack.back()*2) + "]";

				symbolTable.insert($3->getName(), "ID_" + dataType , asmCode);
				asmCode = "SUB SP, 2\n";
			}
			writeToAsm(asmCode, comment, local);
		}
	}
}
| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD 
{
	//done
	std::string codeText($1->getName()+","+$3->getName()+"["+$5->getName()+"]");
	$1->pushParam(SymbolInfo($3->getName(), "ARRAY", std::stoi($5->getName()), ""));

	$1->setName(codeText);
	$$ = $1;
	logCode(codeText, "declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD");

	//asm code
	if(dataType == "VOID")
	{
		errorLog("Variable type cannot be void");
	}
	else
	{
		SymbolInfo* globalAvailability = symbolTable.lookGlobalScope($3->getName());
		if(	globalAvailability != nullptr && isFunction(globalAvailability->getType()) )
		{
			/* global function exist with same name */
			errorLog("Variable can't have the same name as function " + $3->getName());
		}else if(symbolTable.lookCurrentScope($3->getName()) != nullptr){
			errorLog("Multiple declaration of " + $3->getName());
		}else
		{
			std::string comment = "array declaration " + $3->getName() + " of size " + $5->getName();
			std::string asmCode;
			bool local = true;

			if(symbolTable.getCurrentScopeID().size() == 1){
				//global arr

				asmCode = newVarGenerator($3->getName());

				symbolTable.insert($3->getName(), "ARRAY_" + dataType , std::stoi($5->getName()), asmCode);
				asmCode += " DW " + $5->getName() + " DUP(?)\n";
				local = false;
			}else{
				//regular arr

				asmCode = "[BP - " + std::to_string((offsetStack.back() + 1 )*2) + "]";
				offsetStack.back() += std::stoi($5->getName());

				symbolTable.insert($3->getName(), "ARRAY_" + dataType , std::stoi($5->getName()), asmCode);
				asmCode = "SUB SP, " + std::to_string(std::stoi($5->getName()) * 2) + "\n";
			}
			writeToAsm(asmCode, comment, local);
			
		}
	}


}
| declaration_list COMMA ID LTHIRD CONST_FLOAT RTHIRD 
{
	//done
	//no asm required
	std::string codeText($1->getName() +"," +$3->getName() +"[" +$5->getName() +"]");

	$1->setName(codeText);
	$$ = $1;
	errorLog("Array size can not be float");
}
| declaration_list COMMA ID LTHIRD RTHIRD 
{
	//done
	//no asm required
	std::string codeText($1->getName() +","+$3->getName()+"[]");
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

	//asm code
	if(dataType == "VOID")
	{
		errorLog("Variable type cannot be void");
	}
	else
	{
		SymbolInfo* globalAvailability = symbolTable.lookGlobalScope($1->getName());
		if(	globalAvailability != nullptr && isFunction(globalAvailability->getType()) )
		{
			/* global function exist with same name */
			errorLog("Variable can't have the same name as function " + $1->getName());
		}else if(symbolTable.lookCurrentScope($1->getName()) != nullptr){
			errorLog("Multiple declaration of " + $1->getName());
		}else
		{	
			//asm code for var declaration
			std::string comment = "var declaration " + $1->getName();
			std::string asmCode;
			bool local = true;

			if(symbolTable.getCurrentScopeID().size() == 1){ 
				//global vars
				asmCode = newVarGenerator($1->getName());

				symbolTable.insert($1->getName(), "ID_" + dataType , asmCode);
				asmCode += " DW ?\n";
				local = false;
			}else{ 
				//regular vars
				offsetStack.back()++;
				asmCode = "[BP - " + std::to_string(offsetStack.back()*2) + "]";

				symbolTable.insert($1->getName(), "ID_" + dataType , asmCode);
				asmCode = "SUB SP, 2\n";
			}
			writeToAsm(asmCode, comment, local);
		}
	}
}
| ID LTHIRD CONST_INT RTHIRD 
{
	//done
	std::vector<SymbolInfo> paramList;
	std::string codeText($1->getName()+"["+$3->getName()+"]");
	paramList.push_back(SymbolInfo($1->getName(), "ARRAY", std::stoi($3->getName()), " "));

	logCode(codeText, "eclaration_list : ID LTHIRD CONST_INT RTHIRD");
	$$ = new SymbolInfo(codeText, "", paramList, "");

	//asm code
	if(dataType == "VOID")
	{
		errorLog("Variable type cannot be void");
	}
	else
	{
		SymbolInfo* globalAvailability = symbolTable.lookGlobalScope($1->getName());
		if(	globalAvailability != nullptr && isFunction(globalAvailability->getType()) )
		{
			/* global function exist with same name */
			errorLog("Variable can't have the same name as function " + $1->getName());
		}else if(symbolTable.lookCurrentScope($1->getName()) != nullptr){
			errorLog("Multiple declaration of " + $1->getName());
		}else
		{
			std::string comment = "array declaration " + $1->getName() + " of size " + $3->getName();
			std::string asmCode;
			bool local = true;

			if(symbolTable.getCurrentScopeID().size() == 1){
				//global arr

				asmCode = newVarGenerator($1->getName());

				symbolTable.insert($1->getName(), "ARRAY_" + dataType , std::stoi($3->getName()), asmCode);
				asmCode += " DW " + $3->getName() + " DUP(?)\n";
				local = false;
			}else{
				//regular arr

				asmCode = "[BP - " + std::to_string((offsetStack.back() + 1 )*2) + "]";
				offsetStack.back() += std::stoi($3->getName());

				symbolTable.insert($1->getName(), "ARRAY_" + dataType , std::stoi($3->getName()), asmCode);
				asmCode = "SUB SP, " + std::to_string(std::stoi($3->getName()) * 2) + "\n";
			}
			writeToAsm(asmCode, comment, local);
			
		}
	}
}
| ID LTHIRD CONST_FLOAT RTHIRD
{
	//done
	//no asm required
	std::vector<SymbolInfo> paramList;
	std::string codeText($1->getName()+"["+$3->getName()+"]");
	// paramList.push_back(SymbolInfo($1->getName(), "ARRAY", std::stoi($3->getName())));

	errorLog("Array size can not be float");
	$$ = new SymbolInfo(codeText, "", paramList, "");
}
| ID LTHIRD RTHIRD
{
	//done
	//no asm required
	std::vector<SymbolInfo> paramList;
	std::string codeText($1->getName()+"[]");
	// paramList.push_back(SymbolInfo($1->getName(), "ARRAY", std::stoi($3->getName())));

	errorLog("Array size undeclared");
	$$ = new SymbolInfo(codeText, "", paramList, "");
};

statements : statement 
{
	//done
	std::string codeText(indentGen() + $1->getName());
	logCode(codeText, "statements : statement");
	$$ = new SymbolInfo(codeText, "");

	//asm code to remove all temp
	removeTemp();
}
| statements statement 
{
	//done
	std::string codeText($1->getName() + "\n" + indentGen() +$2->getName());
	logCode(codeText, "statements : statements statement");
	$$ = new SymbolInfo(codeText, "");

	//asm code to remove all temp
	removeTemp();
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
};

statement : var_declaration 
{
	//done
	//no asm required
	
	std::string codeText($1->getName() + "\n");
	logCode(codeText, "statement : var_declaration");
	$$ = new SymbolInfo(codeText, "");
}
| expression_statement 
{
	//done
	//no asm required
	
	std::string codeText($1->getName());
	logCode(codeText, "statement : expression_statement");
	$$ = new SymbolInfo(codeText, "");
}
|
{
	//enter scope
	symbolTable.enterScope();
	int temp = offsetStack.back();
	offsetStack.push_back(temp);
	tabSpace++;
}
compound_statement 
{
	//done

	//exit scope
	yacclogfile << "Scope #" << symbolTable.getCurrentScopeID() << " Exited" << std::endl;
	yacclogfile << symbolTable.printAllScopeTable() << std::endl << std::endl;
	symbolTable.exitScope();
	tabSpace--;

	//asm code for removing scope vars
	int temp = offsetStack.back(); 
	offsetStack.pop_back();
	temp -= offsetStack.back();

	if(temp != 0)
	{
		std::string comment = "removing all the variables of the scope\n";
		std::string compiledCode = "ADD SP, " + std::to_string(temp*2) + "\n";

		writeToAsm(compiledCode, comment, true);
	}
	
	std::string codeText($2->getName() + "\n");
	logCode(codeText, "statement : compound_statement");
	$$ = new SymbolInfo(codeText, "");
}
| FOR LPAREN expression_statement //3
{
	std::string label = newLabel("forLoopStart_");
	std::string comment = "for loop start";
	std::string compiledCode = label + ":\n";

	writeToAsm(compiledCode, comment, true);

	$1->setAsm(label);
} 
expression_statement //5
{
	std::string label1 = newLabel("forLoopEnd_");
	std::string label2 = newLabel("forLoopStatement_");
	std::string label3 = newLabel("forLoopChange_");

	std::string comment = "looping condition check";
	std::string compiledCode = "";

	compiledCode += "XOR AX, AX\n";
	compiledCode += "CMP AX, " + $5->getAsm() + "\n";
	compiledCode += "JE " + label1 + "\n";
	compiledCode += "JMP " + label2 + "\n";
	compiledCode += label3 + ":\n";

	writeToAsm(compiledCode, comment, true);

	$3->setAddress(label1);
	$5->setAddress(label2);
	$1->setAddress(label3); 	
} 
expression //7
{
	std::string comment = "looping variable change";
	std::string compiledCode = "";

	compiledCode += "JMP " + $1->getAsm() + "\n";
	compiledCode += $5->getAddress() + ":\n";
	
	writeToAsm(compiledCode, comment, true);
} 
RPAREN statement 
{
	//done
	std::string codeText("for (" +$3->getName() +$5->getName() +$7->getName() + ")" +$10->getName() + "\n");
	logCode(codeText, "statements : FOR LPAREN expression_statement expression_statement expression RPAREN statement");
	$$ = new SymbolInfo(codeText, "");

	//asm code
	std::string comment = "looping statement finished";
	std::string compiledCode = "";
	compiledCode += "JMP " + $1->getAddress() + "\n";
	compiledCode += $3->getAddress() + ":\n";

	writeToAsm(compiledCode, comment, true);
}
| if_declaration %prec LOWER_THAN_ELSE 
{

	std::string comment = "if escape";
	std::string compiledCode = $1->getAddress() + ":\n";
	writeToAsm(compiledCode, comment, true);

	std::string codeText($1->getName());
	logCode(codeText, "statements : IF LPAREN expression RPAREN statement %%prec LOWER_THAN_ELSE");
	$$ = new SymbolInfo(codeText, "");
}
| if_declaration ELSE statement  
{
	std::string comment = "if escape";
	std::string compiledCode = $1->getAddress() + ":\n";

	writeToAsm(compiledCode, comment, true);
	
	std::string codeText($1->getName() +indentGen() + "else " +$3->getName() + "\n");
	logCode(codeText, "statements : IF LPAREN expression RPAREN statement ELSE statement");
	$$ = new SymbolInfo(codeText, "");
}
| WHILE 
{
	std::string comment = "while loop start";
	std::string label = newLabel("while_start");
	std::string compiledCode = label + ":\n";

	writeToAsm(compiledCode, comment, true);
	$1->setAddress(label);
}
LPAREN expression RPAREN 
{
	//asm code
	removeTemp();
	std::string comment = "evaluating while expression";
	std::string compiledCode = "";
	std::string label = newLabel("while_end");
	compiledCode = "MOV AX, 0\n";
	compiledCode += "CMP " + $4->getAsm() + ", AX\n";
	compiledCode += "JE " + label + "\n";

	writeToAsm(compiledCode, comment, true);
	$4->setAddress(label);
}
statement 
{
	//done
	std::string codeText("while ("+$4->getName()+")\n"+$7->getName() + "\n");
	logCode(codeText, "statements : WHILE LPAREN expression RPAREN statement");
	$$ = new SymbolInfo(codeText, "");

	std::string comment = "ending while loop";
	std::string compiledCode = "";
	compiledCode += "JMP " + $1->getAddress() + "\n";
	compiledCode += $4->getAddress() + ":\n";

	writeToAsm(compiledCode, comment, true);
}
| PRINTLN LPAREN expression RPAREN SEMICOLON 
{
	//done

	std::string codeText("printf("+$3->getName()+");\n");
	logCode(codeText, "statements : PRINTLN LPAREN ID RPAREN SEMICOLON");
	$$ = new SymbolInfo(codeText, "");

	//asm code for printing
	std::string comment = "printf(" + $3->getName() + ")";
	std::string asmCode = "SUB SP, " + std::to_string((tempOffset + 1) * 2) + "\n";
	asmCode += "MOV AX, " + $3->getAsm() + "\nCALL PRINT\n";
	asmCode += "ADD SP, " + std::to_string((tempOffset + 1) * 2) + "\n";
	writeToAsm(asmCode, comment, true);
}
| RETURN expression SEMICOLON 
{
	//done
	if(currentReturnType == "VOID")
		errorLog("Void type function can't return value.");
	else
	{
		if(currentReturnType != $2->getType())
			errorLog("Return type mismatch with function declaration in function" + currentFunction);
		else
			functionHasReturned = true;
	}

	std::string codeText("return "+$2->getName()+";");
	logCode(codeText, "statement : RETURN expression SEMICOLON");
	$$ = new SymbolInfo(codeText, "");	

	//asm code for return statement
	std::string comment = "return statement, store value and return to return label";
	std::string compiledCode = "MOV DX, " + $2->getAsm() + "\n";
	
	if(currentFunction == "main")
		compiledCode += "JMP __main_return\n";
	else
		compiledCode += "JMP __" + currentAsmFunction + "_return\n";

	writeToAsm(compiledCode, comment, true);
};

if_declaration : IF LPAREN expression RPAREN
{
	removeTemp();
	
	std::string label = newLabel();
	std::string comment = "evaluating wheather true or not in if statement";
	std::string compiledCode = "";

	compiledCode += "MOV AX, " + $3->getAsm() + "\n";
	compiledCode += "CMP AX, 0\n";
	compiledCode += "JE " + label + "\n";
	
	writeToAsm(compiledCode, comment, true);
	$3->setAddress(label);
} 
statement
{
	std::string label = newLabel();
	std::string compiledCode = "";
	std::string comment = "if not then where";

	compiledCode += "JMP " + label + "\n";
	compiledCode += $3->getAddress() + ":\n";
	
	writeToAsm(compiledCode, comment, true);

	std::string codeText("if (" +$3->getName() +")"+$6->getName() + "\n");
	$$ = new SymbolInfo(codeText, "");
	$$->setAddress(label);
};

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
	$$ = new SymbolInfo(codeText, $1->getType(), $1->getAsm());

	removeTemp();
};

variable : ID 
{
	//done
	//asm passing required

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
	//asm passing required
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
				std::string comment = "array[expression]";

				//two path.. global or local var

				if((closestScopeSymbol->getAsm()).at(0) == '['){ //local var
					std::string compiledCode = "MOV AX, " + $3->getAsm() + "\n";
					compiledCode += "MOV BX, BP\n";
					compiledCode += "SUB BX, " + getOffset(closestScopeSymbol->getAsm()) + "\n";
					compiledCode += "SHL AX, 1\n";
					compiledCode += "SUB BX, AX\n";
					
					asmCode = newTemp();

					//symbolTable.insert(newTemp(), "ID_INT", asmCode);
					compiledCode += "MOV AX, [BX]\n";
					compiledCode += "MOV " + asmCode + ", AX\n";

					address = newTemp();

					//symbolTable.insert(newTemp(), "ID_INT", asmCode);
					compiledCode += "MOV " + address + " , BX\n";

					writeToAsm(compiledCode, comment, true);
				}else{ //global
					std::string compiledCode = "MOV SI, " + closestScopeSymbol->getAsm() + "\n";
					compiledCode += "MOV AX, " + $3->getAsm() + "\n";
					compiledCode += "SHL AX, 1\n";
					compiledCode += "ADD SI, AX\n";
					compiledCode += "MOV AX, [SI]\n";

					asmCode = newTemp();

					compiledCode += "MOV " + asmCode + ", AX\n";

					address = newTemp();

					//symbolTable.insert(newTemp(), "ID_INT", asmCode);
					compiledCode += "MOV " + address + ", SI\n";
					writeToAsm(compiledCode, comment, true);
				}
			}
		}
	}

	logCode(codeText, "variable : ID LTHIRD expression RTHIRD");
	$$ = new SymbolInfo(codeText, returnType, asmCode);
	$$->setAddress(address);
};

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
		std::string comment = $1->getName() + " = " +$3->getName();
		std::string compiledCode = "MOV AX, " + $3->getAsm() + "\n";

		if($1->hasAddress()){
			compiledCode += "MOV BX, " + $1->getAddress() + "\n";
			compiledCode += "MOV [BX], AX\n";
		}else{
			compiledCode += "MOV " + $1->getAsm() + ", AX\n";
		}
		
		writeToAsm(compiledCode, comment, true);
	}
	std::string codeText($1->getName() + "=" +$3->getName());
	logCode(codeText, "expression : variable ASSIGNOP logic_expression");
	$$ = new SymbolInfo(codeText, returnType, $3->getAsm());
};

logic_expression : rel_expression 
{
	//done
	//asm passing required
	std::string codeText($1->getName());
	logCode(codeText, "logic_expression : rel_expression");
	$$ = new SymbolInfo(codeText, $1->getType(), $1->getAsm());
}
| rel_expression LOGICOP
{
	std::string compiledCode = "";
	std::string label =  newLabel(); //pass via logic op address
	std::string asmCode; //pass via logic op asm code

	asmCode = newTemp();

	//asm code
	if($2->getName() == "&&"){
		compiledCode += "MOV AX, " + $1->getAsm() + "\n";
		compiledCode += "MOV " + asmCode + ", AX\n"; 
		compiledCode += "CMP " + $1->getAsm() + ", 0000H\n";
		compiledCode += "JE " + label + "\n";
	}else{
		compiledCode += "MOV AX, " + $1->getAsm() + "\n";
		compiledCode += "MOV " + asmCode + ", AX\n"; 
		compiledCode += "CMP " + $1->getAsm() + ", 0000H\n";
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
	std::string codeText($1->getName()+$2->getName()+$4->getName());


	//asm code
	std::string compiledCode = "";
	compiledCode += "MOV AX, " + $4->getAsm() + "\n";
	compiledCode += "MOV " + $2->getAsm() + ", AX\n"; 
	compiledCode += $2->getAddress() + ":\n";

	writeToAsm(compiledCode, "short circuit end: " + $2->getName() + " " + $4->getName(), true);

	logCode(codeText, "logic_expression : rel_expression LOGICOP rel_expression");
	$$ = new SymbolInfo(codeText, returnType, $2->getAsm());

};

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
	std::string asmCode;
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

		//asm code
		std::string comment($1->getName()+$2->getName()+$3->getName());
		std::string compiledCode = "";

		asmCode = newTemp();

		compiledCode += "MOV AX, " + $1->getAsm() + "\n";
		compiledCode += "MOV BX, " + $3->getAsm() + "\n";
		compiledCode += "CMP AX, BX\n";

		std::string label1 = newLabel();
		std::string label2 = newLabel();

		if($2->getName() == ">"){
			compiledCode += "JG " + label1 + "\n";
		}else if($2->getName() == "<"){
			compiledCode += "JL " + label1 + "\n";
		}else if($2->getName() == ">="){
			compiledCode += "JGE " + label1 + "\n";
		}else if($2->getName() == "<="){
			compiledCode += "JLE " + label1 + "\n";
		}else if($2->getName() == "=="){
			compiledCode += "JE " + label1 + "\n";
		}else{
			compiledCode += "JNE " + label1 + "\n";
		}

		compiledCode += "MOV AX, 0\n";
		compiledCode += "MOV " + asmCode + ", AX\n";
		compiledCode += "JMP " + label2 + "\n";
		compiledCode += label1 + ":\n";
		compiledCode += "MOV AX, 1\n";
		compiledCode += "MOV " + asmCode + ", AX\n";
		compiledCode += label2 + ":\n";

		writeToAsm(compiledCode, comment, true);
		
	}
	std::string codeText($1->getName()+$2->getName()+$3->getName());
	logCode(codeText, "rel_expression : simple_expression RELOP simple_expression");
	$$ = new SymbolInfo(codeText, returnType, asmCode);
};

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
		asmCode = newTemp();

		//symbolTable.insert(newTemp(), "ID_INT", asmCode);

		std::string comment =$1->getName() +$2->getName()+$3->getName();
		std::string compiledCode = "";
		compiledCode += "MOV AX, " + $1->getAsm() + "\n";
		if($2->getName() == "+")
			compiledCode += "ADD AX, " + $3->getAsm() + "\n";
		else
			compiledCode += "SUB AX, " + $3->getAsm() + "\n";
		compiledCode += "MOV " + asmCode + ", AX\n";

		writeToAsm(compiledCode, comment, true);

	}
	std::string codeText($1->getName() +$2->getName() +$3->getName());
	logCode(codeText, "simple_expression : simple_expression ADDOP term");
	$$ = new SymbolInfo(codeText, returnType, asmCode);
};

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
		asmCode = newTemp();

		//symbolTable.insert(newTemp(), "ID_INT", asmCode);
		std::string comment =$1->getName() +$2->getName()+$3->getName();
		std::string compiledCode = "";

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
	std::string codeText($1->getName()+$2->getName()+$3->getName());
	logCode(codeText, "term : term MULOP unary_expression");
	$$ = new SymbolInfo(codeText, returnType, asmCode);
};

unary_expression : ADDOP unary_expression 
{
	//done
	std::string codeText($1->getName() + $2->getName());
	std::string asmCode;
	if($2->getType() == "VOID"){
		//errorLog("Invalid operation.");
		//invalid operation
	}else if($2->getType() == "VOID_FUNC"){
		errorLog("Void function used in expression");
		$2->setType("VOID");
	}else{
		//asm code

		asmCode = newTemp();

		if($1->getName() == "-"){
			std::string comment = codeText;
			std::string compiledCode = "MOV  AX, " + $2->getAsm() + "\n";
			compiledCode += "NEG AX\n";
			compiledCode += "MOV " + asmCode + ", AX\n";

			writeToAsm(compiledCode, comment, true);
		}
	}
	logCode(codeText, "unary_expression : ADDOP unary_expression ");
	$$ = new SymbolInfo(codeText, $2->getType(), asmCode);
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

		asmCode = newTemp();

		//symbolTable.insert(newTemp(), "ID_INT", asmCode);

		std::string compiledCode = "";
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
};

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
	std::string codeText($1->getName()+"("+$3->getName()+")");
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
		compiledCode += "SUB SP, " + std::to_string(2 * tempOffset + 2) + "\n"; //offset stack so function call does not mess with any temp var
		for(int i = args.size() - 1; i >= 0 ; i--){
			compiledCode += "MOV AX, " + args[i].getAsm() + "\n";
			compiledCode += "PUSH AX\n"; 
		}
		compiledCode += "CALL " + globalAvailability->getAsm() + "\n";
		compiledCode += "MOV BX, " + std::to_string(args.size() * 2 + 6) + "\n";
		compiledCode += "MOV AX, SP\n";
		compiledCode += "SUB AX, BX\n";
		compiledCode += "MOV SI, AX\n";
		compiledCode += "MOV DX, [SI]\n"; 
		compiledCode += "ADD SP, " + std::to_string(2 * tempOffset + 2) + "\n"; //remove that offset for regular continuation
		std::string asmCode = newTemp();

		//symbolTable.insert(newTemp(), "ID_INT", asmCode);
		compiledCode += "MOV " + asmCode + ", DX";
		
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
	std::string asmCode = newTemp();

	//symbolTable.insert(newTemp(), "ID_INT", asmCode);
	std::string compiledCode = "MOV AX, " + $1->getName() + "\n";
	compiledCode += "MOV " + asmCode + ", AX\n";
	writeToAsm(compiledCode, "CONST_INT: " + $1->getName(), true);

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
	std::string asmCode;
	if($1->getType() == "VOID"){
		errorLog("Invalid operation.");
	}else{
		returnType = $1->getType();

		//asm code
		asmCode = newTemp();
		std::string comment = codeText;
		std::string compiledCode = "MOV AX, " + $1->getAsm() + "\n";  
		compiledCode += "MOV " + asmCode + ", AX\n";
		compiledCode += "INC " + $1->getAsm() + "\n";

		if($1->hasAddress()){ //if this is an array, also increase the data on the real address too
			compiledCode += "MOV SI, " + $1->getAddress() + "\n";
			compiledCode += "MOV AX, " + $1->getAsm() + "\n";
			compiledCode += "MOV [SI], AX\n"; 
		}

		writeToAsm(compiledCode, comment, true);

	}
	logCode(codeText, "factor : variable INCOP");
	$$ = new SymbolInfo(codeText, returnType, asmCode);
}
| variable DECOP 
{
	//done
	std::string returnType("VOID");
	std::string codeText($1->getName() + "--");
	std::string asmCode;
	if($1->getType() == "VOID"){
		errorLog("Invalid operation.");
	}else{
		returnType = $1->getType();

		//asm code
		asmCode = newTemp();
		std::string comment = codeText;
		std::string compiledCode = "MOV AX, " + $1->getAsm() + "\n";  
		compiledCode += "MOV " + asmCode + ", AX\n";
		compiledCode += "DEC " + $1->getAsm() + "\n";

		if($1->hasAddress()){ //if this is an array, also increase the data on the real address too
			compiledCode += "MOV SI, " + $1->getAddress() + "\n";
			compiledCode += "MOV AX, " + $1->getAsm() + "\n";
			compiledCode += "MOV [SI], AX\n"; 
		}

		writeToAsm(compiledCode, comment, true);
	}
	logCode(codeText, "factor : variable DECOP");
	$$ = new SymbolInfo(codeText, returnType, asmCode);
};

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
};


arguments : arguments COMMA logic_expression 
{
	$1->pushParam(SymbolInfo("", $3->getType(), $3->getAsm()));
	std::string codeText($1->getName()+ ","+$3->getName());

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

    lexlogfile.open("logs/1805055_lex_log.txt");
    lextokenfile.open("logs/1805055_lex_token.txt");

    yacclogfile.open("logs/1805055_yacc_log.txt");
    errorFile.open("logs/1805055_yacc_error.txt");

	asmFile.open("generatedCode/1805055_asm_code.asm");
	optimizedAsmFile.open("generatedCode/1805055_optimized_asm_code.asm");
	debugFile.open("generatedCode/debug_buffer.txt");
	initAsmCode(1000);

	formattedCode.open("logs/1805055_formatted_code.txt");

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