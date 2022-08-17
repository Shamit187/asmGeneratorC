#include <iostream>
#include "ScopeTableClass/SymbolTable.h"
#include <fstream>
#include <algorithm>

#define INT_TYPE 0
#define FLOAT_TYPE 1
#define EXTRA_DECIMAL 2
#define ILL_FORMAT 3

#define CHAR_TYPE 0
#define MULTIWORD_CHAR 1
#define UNTERMINATED_CHAR 2
#define EMPTY_CHAR 3

#define STRING_TYPE 0
#define UNTERMINATED_STRING 1
#define UNRECOGNIZED_STRING 2

enum operators{ ADD, MINUS, 
                MUL, DIV, MOD, 
                INC, DEC, 
                LT, LE, GT, GE, EQU, NE, 
                ASSIGN, 
                AND, OR, 
                NOT_TOKEN, 
                LPAREN_TOKEN, RPAREN_TOKEN,
                LCURL_TOKEN, RCURL_TOKEN,
                LTHIRD_TOKEN, RTHIRD_TOKEN,
                COMMA_TOKEN, SEMICOLON_TOKEN};

using namespace std;

ofstream lexlogfile;
ofstream lextokenfile;

unsigned int lineCount = 1;
unsigned int lexErrorCount = 0;

string stringBuffer;
string stringLexemeBuffer;
string charBuffer;
char charToken;
string commentBuffer;

//util function
/*
 * Erase all Occurrences of given substring from main string.
 */
void eraseAllSubStr(std::string & mainStr, const std::string & toErase)
{
    size_t pos = std::string::npos;
    // Search for the substring in string in a loop untill nothing is found
    while ((pos  = mainStr.find(toErase) )!= std::string::npos)
    {
        // If found then erase it from string
        mainStr.erase(pos, toErase.length());
    }
}

void unrecognizedChar(string input){
    if(input[0] == '#')
        lexlogfile << endl << "Error at line no " << lineCount << ": No available Preprocessor, # found" << endl;
    else
        lexlogfile << endl << "Error at line no " << lineCount << ": Unrecognized character " << input << endl;
    lexErrorCount++;
}

//comment related function
void singleLineComment(string comment){
    int count = std::count(comment.begin(), comment.end(), '\n');
    // comment.erase(0,2);
    // comment.pop_back();
    lexlogfile << endl << "Line no " << lineCount << ": " << "Token <COMMENT> Lexeme " << comment << " found" << endl << endl;
    lineCount += count;
}

//multiline comment
void insertCommentBuffer(string input){
    commentBuffer.append(input);
}

void multiLineComment(string comment){
    comment.append(commentBuffer);
    commentBuffer.clear();
    int count = std::count(comment.begin(), comment.end(), '\n');
    // comment.erase(0,2);
    // comment.pop_back(); comment.pop_back();
    lexlogfile << endl << "Line no " << lineCount << ": " << "Token <COMMENT> Lexeme " << comment << " found" << endl << endl;
    lineCount += count;
}

void multiLineCommentError(){
    string comment;
    comment.append(commentBuffer);
    commentBuffer.clear();
    int count = std::count(comment.begin(), comment.end(), '\n');
    lexlogfile << endl << "Error at line no " << lineCount << ": Unterminated comment " << comment << endl;
    lineCount += count;
    lexErrorCount++;
}


//keyword based function
void keywordTokenizer(string keyword){

    //wrapping <> + uppercase
    string keywordToken = keyword;
    transform(keywordToken.begin(), keywordToken.end(), keywordToken.begin(), ::toupper);
    keywordToken.insert(0, 1, '<');
    keywordToken.push_back('>');
    
    //push log and token
    lexlogfile << endl << "Line no " << lineCount << ": " << "Token " << keywordToken << " Lexeme " << keyword << " found" << endl;
    lextokenfile << keywordToken << " ";

}


//id based function
void identifierTokenizer(string identifier){

    //wrapping <> + uppercase
    string idToken = "<ID";
    idToken.push_back(',');
    idToken.push_back(' ');
    idToken.append(identifier);
    idToken.push_back('>');

    //push log and token
    lexlogfile << endl << "Line no " << lineCount << ": " << "Token <ID> Lexeme " << identifier << " found" << endl << endl;
    lextokenfile << idToken << " ";
}

//operator based function
void tokenizeOperator(unsigned int choice, string input){
    switch (choice)
    {
    case ADD:case MINUS:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <ADDOP> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<ADDOP, " << input << "> ";
        break;
    case MUL:case DIV:case MOD:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <MULOP> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<MULOP, " << input << "> ";
        break;
    case INC:case DEC:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <INCOP> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<INCOP, " << input << "> ";
        break;
    case LT:case LE:case GT:case GE:case EQU:case NE:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <RELOP> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<RELOP, " << input << "> ";
        break;
    case ASSIGN:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <ASSIGNOP> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<ASSIGNOP, " << input << "> ";
        break;
    case AND:case OR:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <LOGICOP> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<LOGICOP, " << input << "> ";
        break;
    case NOT_TOKEN:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <NOT> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<NOT, " << input << "> ";
        break;
    case LPAREN_TOKEN:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <LPAREN> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<LPAREN, " << input << "> ";
        break;
    case RPAREN_TOKEN:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <RPAREN> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<RPAREN, " << input << "> ";
        break;
    case LCURL_TOKEN:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <LCURL> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<LCURL, " << input << "> ";
        lextokenfile << endl; //unnecessary
        break;
    case RCURL_TOKEN:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <RCURL> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<RCURL, " << input << "> ";
        lextokenfile << endl; //unnecessary
        break;
    case LTHIRD_TOKEN:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <LTHIRD> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<LTHIRD>, " << input << "> ";
        break;
    case RTHIRD_TOKEN:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <RTHIRD> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<RTHIRD, " << input << "> ";
        break;
    case COMMA_TOKEN:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <COMMA> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<COMMA, " << input << "> ";
        break;
    case SEMICOLON_TOKEN:
        lexlogfile << endl << "Line no "<<lineCount<<": Token <SEMICOLON> Lexeme "<<input<<" found"<<endl;
        lextokenfile << "<SEMICOLON, " << input << "> ";
        lextokenfile << endl; //unnecessary
        break;
    default:
        break;
    }
}


//number based function
void tokenizeConstNumerals(string input, unsigned int choice){
    switch (choice)
    {
    case INT_TYPE:
        lexlogfile << endl << "Line no " << lineCount << ": " << "Token <CONST_INT> Lexeme " << input << " found" << endl;
        lextokenfile << "<CONST_INT, " << input << "> ";
        break;
    case FLOAT_TYPE:
        lexlogfile << endl << "Line no " << lineCount << ": " << "Token <CONST_FLOAT> Lexeme " << input << " found" << endl;
        lextokenfile << "<CONST_FLOAT, " << input << "> ";
        break;
    case EXTRA_DECIMAL:
        lexlogfile << endl << "Error at line no " << lineCount << ": " << "Too many decimal points  " << input << endl;
        lexErrorCount++;
        break;
    case ILL_FORMAT:
        lexlogfile << endl << "Error at line no " << lineCount << ": " << "Ill formed number  " << input << endl;
        lexErrorCount++;
        break;
    default:
        break;
    }
}

//character buffer
void insertCharBuffer(string input){
    charBuffer.push_back(input[0]);
    charToken = input[0];
}

void insertCharBufferEscape(string input){
    charBuffer.push_back('\\');
    charBuffer.push_back(input[0]);
    switch (input[0])
    {
    case 'n':
        charToken = '\n';
        break;
    case 't':
        charToken = '\t';
        break;
    case '\\':
        charToken = '\\';
        break;
    case '\'':
        charToken = '\'';
        break;
    case 'a':
        charToken = '\a';
        break;
    case 'f':
        charToken = '\f';
        break;
    case 'r':
        charToken = '\r';
        break;
    case 'b':
        charToken = '\b';
        break;
    case 'v':
        charToken = '\v';
        break;
    case '0':
        charToken = '\0';
        break;
    case '\"':
        charToken = '\"';
        break;
    default:
        break;
    }
}

void insertCharWrong(string input){
    charBuffer.append(input);
}

void flushCharBuffer(unsigned int choice){
    switch (choice)
    {
    case CHAR_TYPE:
        lexlogfile << endl << "Line no " << lineCount << ": " << "Token <CONST_CHAR> Lexeme '" << charBuffer 
                << "' found --> " << "<CONST_CHAR, '" << charToken << "'> " << endl;
        lextokenfile << "<CONST_CHAR, " << charBuffer << "> ";
        break;
    case MULTIWORD_CHAR:
        lexErrorCount++;
        lexlogfile << endl << "Error at line no " << lineCount << ": Multi character constant error '" << charBuffer << '\'' << endl;
        break;
    case UNTERMINATED_CHAR:
        lexErrorCount++;
        lexlogfile << endl << "Error at line no " << lineCount << ": Unterminated character '" << charBuffer << endl;
        break;
    case EMPTY_CHAR:
        lexErrorCount++;
        lexlogfile << endl << "Error at line no " << lineCount << ": Empty character constant error ''" << endl;
    default:
        break;
    }
    charBuffer.clear();
}


//string based functions
void insertStringBuffer(string input){
    stringBuffer.append(input);
    stringLexemeBuffer.append(input);

}

void insertEscStringBuffer(string input){
    switch (input[0])
    {
    case 'n':
        stringBuffer.push_back('\n');
        stringLexemeBuffer.append("\\n");
        break;
    case 't':
        stringBuffer.push_back('\t');
        stringLexemeBuffer.append("\\t");
        break;
    case '\\':
        stringBuffer.push_back('\\');
        stringLexemeBuffer.append("\\\\");
        break;
    case '\'':
        stringBuffer.push_back('\'');
        stringLexemeBuffer.append("\\\'");
        break;
    case 'a':
        stringBuffer.push_back('\a');
        stringLexemeBuffer.append("\\a");
        break;
    case 'f':
        stringBuffer.push_back('\f');
        stringLexemeBuffer.append("\\f");
        break;
    case 'r':
        stringBuffer.push_back('\r');
        stringLexemeBuffer.append("\\r");
        break;
    case 'b':
        stringBuffer.push_back('\b');
        stringLexemeBuffer.append("\\b");
        break;
    case 'v':
        stringBuffer.push_back('\v');
        stringLexemeBuffer.append("\\v");
        break;
    case '0':
        stringBuffer.push_back('\0');
        stringLexemeBuffer.append("\\0");
        break;
    case '\"':
        stringBuffer.push_back('\"');
        stringLexemeBuffer.append("\\\"");
        break;
    default:
        break;
    }
}

std::string flushStringBuffer(unsigned int choice){
    switch (choice)
    {
    case STRING_TYPE:
        lexlogfile << endl << "Line no "<< lineCount <<": Token <STRING> Lexeme \"" << stringLexemeBuffer << "\" found" ;
        eraseAllSubStr(stringBuffer, "\\\n");
        lexlogfile << "--> <STRING, " << stringBuffer << ">" << endl;
        lextokenfile << "<STRING, " << stringBuffer << "> ";
        break;
    case UNTERMINATED_STRING:
        lexErrorCount++;
        lextokenfile << endl; //unnecessary
        lexlogfile << endl << "Error at line no "<< lineCount <<": Unterminated string \"" << stringLexemeBuffer << " found" << endl;
        break;
    case UNRECOGNIZED_STRING:
        lexErrorCount++;
        lextokenfile << endl; //unnecessary
        lexlogfile << endl << "Error at line no "<< lineCount <<": Unrecognized escape character \"" << stringLexemeBuffer << " found" << endl;
        break;  
    default:
        break;
    }
    std::string returnString {stringLexemeBuffer};
    stringBuffer.clear();
    stringLexemeBuffer.clear();
    return returnString;
}