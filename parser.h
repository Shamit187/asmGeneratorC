#include "ScopeTableClass/SymbolTable.h"
#include <fstream>
#include <sstream>
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
std::ofstream optimizedAsmFile;
std::ofstream debugFile;
std::vector<int> offsetStack;
int tempOffset = 0;
std::string dataType;
std::string currentAsmFunction;
std::ofstream formattedCode;
std::ofstream dataPortion;

//

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

//asm related functions

//declerations
std::string newFuncGenerator(std::string funcName);
std::string newVarGenerator(std::string varName);
void writeToAsm(std::string asmCode, std::string comment, bool indent);
void initAsmCode(int stackSize);
std::vector<std::string> splitString(std::string ls, char delim);
std::string newLabel();
std::string newLabel(std::string type_of_label);
std::string getOffset(std::string asmCode);
std::string newTemp();
void removeTemp();
void writeToData(std::string asmCode);
void createAsmFile();


//definitions
void createAsmFile(int stackSize){
    std::ofstream normal{"generatedCode/asmCode.asm"};
    std::ofstream optimized{"generatedCode/optimizedAsmCode.asm"};
    std::string line;
    std::ifstream input;

    normal << ".MODEL SMALL\n.STACK " + std::to_string(stackSize) + "\n\n.DATA\n";
    optimized << ".MODEL SMALL\n.STACK " + std::to_string(stackSize) + "\n\n.DATA\n";

    //writeData
    input.open("asmLibrary/data.txt", std::ifstream::in);
    while (getline(input, line)) {
        normal << line << "\n";
        optimized << line << "\n";
    }
    input.close();

    normal << "\n.CODE\n\n";
    optimized << "\n.CODE\n\n";

    //writePrintProc
    input.open("asmLibrary/printProc.txt", std::ifstream::in);
    while (getline(input, line)) {
        normal << line << "\n";
        optimized << line << "\n";
    }
    input.close();

    //writeInputProc
    input.open("asmLibrary/inputProc.txt", std::ifstream::in);
    while (getline(input, line)) {
        normal << line << "\n";
        optimized << line << "\n";
    }
    input.close();

    //compiledIndication
    input.open("asmLibrary/compiledCodeIndicator.txt", std::ifstream::in);
    while (getline(input, line)) {
        normal << line << "\n";
        optimized << line << "\n";
    }
    input.close();


    //normal
    input.open("asmLibrary/compiledCode.txt", std::ifstream::in);
    while (getline(input, line)) {
        normal << line << "\n";
    }
    input.close();


    //optimized
    input.open("asmLibrary/optimizedCode.txt", std::ifstream::in);
    while (getline(input, line)) {
        optimized << line << "\n";
    }
    input.close();

    normal.close();
    optimized.close();
}

std::string newFuncGenerator(std::string funcName){
    static unsigned functionNumber = 0;
    functionNumber++;
    return funcName + std::to_string(functionNumber);
}

std::string newVarGenerator(std::string varName){
    static unsigned globalVarCounter = 0;
    globalVarCounter++;
    return varName + std::to_string(globalVarCounter);
}

void writeToData(std::string asmCode){
    dataPortion << asmCode;
}

void writeToAsm(std::string asmCode, std::string comment, bool indent){
    static std::string prevLine = "     ";
    static std::string moveCommand = "MOV";
    static std::string prevMovFrom = "null";
    static std::string prevMovTo = "null";

    asmFile << "    ;" << comment << std::endl;

    std::string line;   
    std::stringstream asmLines(asmCode); 
    while (std::getline(asmLines, line, '\n')) {

        //optimization code
        if(!line.empty() && !prevLine.empty())
        {
            std::vector < std::string > current = splitString(line, ' ');
            std::vector < std::string > prev = splitString(prevLine, ' ');
            

            //mov optimization
            if(current[0].compare(moveCommand) == 0 && prev[0].compare(moveCommand) == 0){

                std::string tempString_0{line};
                tempString_0.erase(0,4);
                std::vector < std::string > x = splitString(tempString_0, ',');
                x[1].erase(0,1);
                //debugFile << "moving from " << x[1] << " to " << x[0] << std::endl;

                std::string tempString_1{prevLine};
                tempString_1.erase(0,4);
                std::vector < std::string > y = splitString(tempString_1, ',');
                y[1].erase(0,1);
                // std::vector < std::string > y;
                // y.push_back("hello");
                // y.push_back("or");

                if(x[0] == y[1] && y[0] == x[1]){
                    // debugFile << x[0] << " " << x[1] << " " << y[0] << " " << y[1] << std::endl;
                    // optimizedAsmFile << prevLine << std::endl;
                    optimizedAsmFile << ";" << line << " Optimized" << std::endl;
                }else if(x[0] == y[0] && y[1] == x[1]){
                    // debugFile << x[0] << " " << x[1] << " " << y[0] << " " << y[1] << std::endl;
                    // optimizedAsmFile <<  prevLine << std::endl;
                    optimizedAsmFile <<  ";" << line << " Optimized" << std::endl;
                }else{
                    optimizedAsmFile <<  prevLine << std::endl;
                    prevLine = line;
                }
            }else{
                optimizedAsmFile <<  prevLine << std::endl;
                prevLine = line;
            }
        }

        //normal code
        asmFile <<  (indent ? "\t":"") << line << std::endl;
    }

    asmFile << std::endl << std::endl;
}

void initAsmCode(int stackSize){

    std::string line;
    
    //model and stack size
    asmFile << ".MODEL SMALL\n";
    asmFile << ".STACK " + std::to_string(stackSize) + "\n";
    asmFile << ".DATA\n\n.CODE\n";

    optimizedAsmFile << ".MODEL SMALL\n";
    optimizedAsmFile << ".STACK " + std::to_string(stackSize) + "\n";
    optimizedAsmFile << ".DATA\n\n.CODE\n";

    //print procedure
    std::ifstream ini_file_1{
        "asmLibrary/printProc.txt"
    };
    while (getline(ini_file_1, line)) {
        asmFile << line << "\n";
        optimizedAsmFile << line << "\n";
    }

    //indicator
    std::ifstream ini_file_2{
        "asmLibrary/compiledCodeIndicator.txt"
    };
    while (getline(ini_file_2, line)) {
        asmFile << line << "\n";
        optimizedAsmFile << line << "\n";
    }

    asmFile << std::endl;

}

std::vector<std::string> splitString(std::string ls, char delim) {
    std::stringstream stream(ls);
    std::vector<std::string> v;
    std::string temp;
    while(getline(stream, temp, delim)) {
        v.push_back(temp);
    }
    return v;
}

std::string arrayOffset(std::string asmCode, int index){
    std::string returnString;
    if(asmCode[0] == '['){
        std::vector<std::string>v = splitString(asmCode, ' ');
        if(v[2] == "-"){
            returnString = "[ " + v[1] + " - " + std::to_string(std::stoi(v[3]) + index*2) + " ]";
        }else{
            returnString = "[ " + v[1] + " + " + std::to_string(std::stoi(v[3]) - index*2) + " ]";
        }
    }else{
        returnString = "[" + asmCode + " + " + std::to_string(index) + "]";
    }
    return returnString;
}

std::string newLabel(){
    static int lebelNumber = 0;
    
    std::string temp = "__lebel" + std::to_string(lebelNumber++);
    return temp;
}

std::string newLabel(std::string type_of_label){
    static int lebelNumber = 0;
    
    std::string temp = "__lebel_" + type_of_label + std::to_string(lebelNumber++);
    return temp;
}

std::string getOffset(std::string asmCode){
    std::vector<std::string>v = splitString(asmCode, ' ');
    std::string returnString = v[2];
    returnString.pop_back();
    // std::cout << asmCode << " : " << returnString << std::endl;
    return returnString;
}

std::string newTemp(){
    tempOffset++;
    std::string asmCode = "[BP - " + std::to_string((offsetStack.back() + tempOffset)*2) + "]";
    return asmCode;
}

void removeTemp(){
    tempOffset = 0;
}
