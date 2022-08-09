#include "ScopeTableClass/SymbolTable.h"
#include <fstream>
#include <algorithm>
#include <vector>
#include <stack>

using namespace std;

#define SYMBOLTABLE_SIZE 20

int yyparse(void);
int yylex(void);
extern FILE* yyin;
FILE* inputFile;

extern std::ofstream lexlogfile;
extern std::ofstream lextokenfile;

std::ofstream yacclogfile;
std::ofstream errorFile;

//asm code
std::ofstream asmFile;
std::stack<int> offsetStack;
int currentOffset = 0;

extern unsigned int lineCount;
extern unsigned int lexErrorCount;

unsigned int yaccErrorCount = 0;
unsigned int yaccWarningCount = 0;

void yyerror(const char* str) {
    errorFile << "Syntax error at line:" << lineCount << ": " << str << " \n\n";
    yacclogfile << "Syntax error at line:" << lineCount << ": " << str << " \n\n";
    yaccErrorCount++;
}

//important
SymbolTable symbolTable(SYMBOLTABLE_SIZE);

std::string currentReturnType;
std::string currentFunction;
bool functionHasReturned;

int tabSpace = 0;

void logCode(std::string code, std::string rule){
    yacclogfile << "Line " << lineCount << ": " << rule << std::endl << std::endl;
	yacclogfile << code << std::endl << std::endl;
}

void errorLog(std::string errorText){
    yaccErrorCount++;
    yacclogfile << "Error at line " << lineCount << ": " << errorText << std::endl << std::endl;
    errorFile << "Error at line " << lineCount << ": " << errorText << std::endl << std::endl;
}

void warningLog(std::string warningText){
    yaccWarningCount++;
    yacclogfile << "Warning at line " << lineCount << ": " << warningText << std::endl << std::endl;
    errorFile << "Warning at line " << lineCount << ": " << warningText << std::endl << std::endl;
}

bool isFunction(std::string type){
    return type == "FUNC_INT" || type == "FUNC_FLOAT" || type == "FUNC_VOID";
}

bool isID(std::string type){
    return type == "ID_INT" || type == "ID_FLOAT";
}

bool isArray(std::string type){
    return type == "ARRAY_INT" || type == "ARRAY_FLOAT";
}

std::string typeReturn(std::string type){
    if(type == "FUNC_INT" || type == "ID_INT" || type == "ARRAY_INT") return "INT";
    if(type == "FUNC_FLOAT" || type == "ID_FLOAT" || type == "ARRAY_FLOAT") return "FLOAT";
    else return "VOID";
}

std::string vartypeReturn(std::string type){
    if(type == "FUNC_INT" || type == "FUNC_FLOAT" || type == "FUNC_VOID") return "function";
    if(type == "ID_INT" || type == "ID_FLOAT") return "static variable";
    if(type == "ARRAY_INT" || type == "ARRAY_FLOAT") return "array";
    else return "VOID";
}

std::string indentGen(){
    int i = tabSpace;
    if(i <= 0) return "";
    else{
        std::string returnStr("");
        for(int x = 0; x < i; x++){
            returnStr += "\t";
        }
        return returnStr;
    }
}

unsigned functionNumber = 0;
std::string currentAsmFunction;
std::string newFuncGenerator(std::string funcName){
    functionNumber++;
    return funcName + std::to_string(functionNumber);
}

unsigned globalVarCounter = 0;
std::string newVarGenerator(std::string varName){
    globalVarCounter++;
    return varName + std::to_string(globalVarCounter);
}

void initAsmCode(){

    std::string line;
    std::ifstream ini_file{
        "init.txt"
    };
    while (getline(ini_file, line)) {
        asmFile << line << "\n";
    }
}