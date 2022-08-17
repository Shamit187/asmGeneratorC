%option noyywrap

%x CHAR_ENTRY
%x CHAR_ESCAPE
%x CHAR_READ
%x CHAR_ERROR

%x STRING_START
%x STRING_ESCAPE
%x STRING_ERROR
%x STRING_ERROR_ENTER

%x MLCOMENT
%x MLCOMENTSTAR

%{
    #include "ScopeTableClass/SymbolTable.h"
    #include "scanner.h"

    #include "y.tab.h"

    #define YYSTYPE SymbolInfo*
    std::string stringToken;
%}

LETTER [a-zA-Z]
LETTER_ {LETTER}|_
DIGIT [0-9]
HORIGAP [ \t]
VERTGAP [\n\r]
DECPOINT \.
ESCCHAR [nt\\'afrbv0\"]
SINGQUO [']
DUOQUO \"

DOUBLESLASH "//"
NOTSLASHENTER [^\n\r]
SLASHCOMMENT {DOUBLESLASH}{NOTSLASHENTER}*("\\\n"{NOTSLASHENTER}*)*"\n"

SLASHSTAR "/*"

EXPONENT [eE][-+]?[0-9]+
INTNUM [0-9]+
FRACNUM [0-9]*{DECPOINT}[0-9]+
INTFLOAT {INTNUM}|{FRACNUM}
EXPFLOAT {INTFLOAT}{EXPONENT}

%%


{HORIGAP}+ {}
{VERTGAP} {lineCount++;}

"#include"{HORIGAP}+[^\n]*"\n" {unrecognizedChar("#");lineCount++;}
"#define"{HORIGAP}+[^\n]*"\n" {unrecognizedChar("#");lineCount++;}
 
{SLASHCOMMENT} {singleLineComment(yytext);}

{SLASHSTAR} {BEGIN (MLCOMENT);insertCommentBuffer(yytext);}
<MLCOMENT>[\*] {BEGIN (MLCOMENTSTAR);insertCommentBuffer(yytext);}
<MLCOMENT><<EOF>> {BEGIN(INITIAL); multiLineCommentError();}
<MLCOMENT>{VERTGAP} {insertCommentBuffer(yytext);}
<MLCOMENT>. {insertCommentBuffer(yytext);}

<MLCOMENTSTAR>[/] {BEGIN (INITIAL); multiLineComment(yytext);}
<MLCOMENTSTAR>{VERTGAP} {BEGIN (MLCOMENT);insertCommentBuffer(yytext);}
<MLCOMENTSTAR>. {BEGIN (MLCOMENT);insertCommentBuffer(yytext);}


"++" {tokenizeOperator(INC, yytext);return INCOP;}
"--" {tokenizeOperator(DEC, yytext);return DECOP;}
"<=" {tokenizeOperator(LE, yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "RELOP");return RELOP;}
">=" {tokenizeOperator(GE, yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "RELOP");return RELOP;}
"==" {tokenizeOperator(EQU,yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "RELOP");return RELOP;}
"!=" {tokenizeOperator(NE, yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "RELOP");return RELOP;}
"&&" {tokenizeOperator(AND, yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "LOGICOP");return LOGICOP;}
"||" {tokenizeOperator(OR, yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "LOGICOP");return LOGICOP;}
"+" {tokenizeOperator(ADD, yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "ADDOP");return ADDOP;}
"-" {tokenizeOperator(MINUS, yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "ADDOP");return ADDOP;}
"*" {tokenizeOperator(MUL, yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "MULOP");return MULOP;}
"/" {tokenizeOperator(DIV, yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "MULOP");return MULOP;}
"\%" {tokenizeOperator(MOD, yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "MULOP");return MULOP;}
"<" {tokenizeOperator(LT, yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "RELOP");return RELOP;}
">" {tokenizeOperator(GT, yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "RELOP");return RELOP;}
"=" {tokenizeOperator(ASSIGN, yytext);return ASSIGNOP;}
"!" {tokenizeOperator(NOT_TOKEN, yytext);return NOT;}
"(" {tokenizeOperator(LPAREN_TOKEN, yytext);return LPAREN;}
")" {tokenizeOperator(RPAREN_TOKEN, yytext);return RPAREN;}
"[" {tokenizeOperator(LTHIRD_TOKEN, yytext);return LTHIRD;}
"]" {tokenizeOperator(RTHIRD_TOKEN, yytext);return RTHIRD;}
"{" {tokenizeOperator(LCURL_TOKEN, yytext);return LCURL;}
"}" {tokenizeOperator(RCURL_TOKEN, yytext);return RCURL;}
"," {tokenizeOperator(COMMA_TOKEN, yytext);return COMMA;}
";" {tokenizeOperator(SEMICOLON_TOKEN, yytext);return SEMICOLON;}


"if" {keywordTokenizer(yytext);return IF;}
"for" {keywordTokenizer(yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "FOR");return FOR;}
"int" {keywordTokenizer(yytext);return INT;}
"float" {keywordTokenizer(yytext);return FLOAT;}
"void"  {keywordTokenizer(yytext);return VOID;}
"else" {keywordTokenizer(yytext);return ELSE;}
"while" {keywordTokenizer(yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "WHILE");return WHILE;}
"return" {keywordTokenizer(yytext);return RETURN;}
"println" {keywordTokenizer(yytext);return PRINTLN;}
"input" {keywordTokenizer(yytext);return INPUT;}

{LETTER_}({LETTER_}|{DIGIT})* {identifierTokenizer(yytext);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "ID");return ID;}


[0]* {tokenizeConstNumerals(yytext, INT_TYPE);yylval.symbolInfo = (YYSTYPE) new SymbolInfo("0", "CONST_INT"); return CONST_INT;}
{EXPFLOAT}{DECPOINT}({LETTER_}|{DIGIT})* {tokenizeConstNumerals(yytext, ILL_FORMAT);}
{EXPFLOAT}{LETTER_}({DIGIT}|{DECPOINT})* {tokenizeConstNumerals(yytext, ILL_FORMAT);}
{EXPFLOAT} {tokenizeConstNumerals(yytext, FLOAT_TYPE); yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "CONST_FLOAT"); return CONST_FLOAT;}
{INTNUM}{LETTER_}({LETTER_}|{DIGIT})* {tokenizeConstNumerals(yytext, ILL_FORMAT);}
{FRACNUM}({DECPOINT}[0-9]*)+({LETTER_}|{DIGIT}|{DECPOINT})* {tokenizeConstNumerals(yytext, EXTRA_DECIMAL);}
{EXPFLOAT}({DECPOINT}[0-9]*)+ {tokenizeConstNumerals(yytext, ILL_FORMAT);}
{INTNUM}{DECPOINT} {tokenizeConstNumerals(yytext, ILL_FORMAT);}

{INTNUM} {tokenizeConstNumerals(yytext, INT_TYPE);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "CONST_INT"); return CONST_INT;}
{FRACNUM} {tokenizeConstNumerals(yytext, FLOAT_TYPE);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(yytext, "CONST_FLOAT"); return CONST_FLOAT;}

{SINGQUO} {BEGIN (CHAR_ENTRY);}

<CHAR_ENTRY>[\\] {BEGIN (CHAR_ESCAPE);}
<CHAR_ENTRY>{VERTGAP} {BEGIN (INITIAL); flushCharBuffer(UNTERMINATED_CHAR);lineCount++;}
<CHAR_ENTRY>[']	{BEGIN (INITIAL); flushCharBuffer(EMPTY_CHAR);}
<CHAR_ENTRY>[^\\] {BEGIN (CHAR_READ);insertCharBuffer(yytext);}

<CHAR_ESCAPE>{ESCCHAR} {BEGIN (CHAR_READ);insertCharBufferEscape(yytext);}
<CHAR_ESCAPE>[^\n']+ {BEGIN (CHAR_ERROR);insertCharWrong(yytext);}

<CHAR_ERROR>[\n] {BEGIN (INITIAL);flushCharBuffer(UNTERMINATED_CHAR);lineCount++;}
<CHAR_ERROR>{SINGQUO} {BEGIN(INITIAL);flushCharBuffer(MULTIWORD_CHAR);}

<CHAR_READ>[^\n']+ {BEGIN (CHAR_ERROR);insertCharWrong(yytext);}
<CHAR_READ>{SINGQUO} {BEGIN (INITIAL);flushCharBuffer(CHAR_TYPE);}
<CHAR_READ>[\n] {BEGIN (INITIAL);flushCharBuffer(UNTERMINATED_CHAR);lineCount++;}
<CHAR_READ><<EOF>> {BEGIN (INITIAL);flushCharBuffer(UNTERMINATED_CHAR);lineCount++;}

{DUOQUO} {BEGIN (STRING_START);}

<STRING_START>[^\\\n\"]* {insertStringBuffer(yytext);}
<STRING_START>[\\] {BEGIN (STRING_ESCAPE);}
<STRING_START>{VERTGAP} {BEGIN (INITIAL);lineCount++;flushStringBuffer(UNTERMINATED_STRING);}
<STRING_START>{DUOQUO} {BEGIN (INITIAL);stringToken = flushStringBuffer(STRING_TYPE);yylval.symbolInfo = (YYSTYPE) new SymbolInfo(stringToken, "STRING"); return STRING;}
<STRING_START><<EOF>> {BEGIN (INITIAL);lineCount++;flushStringBuffer(UNTERMINATED_STRING);}

<STRING_ESCAPE>{ESCCHAR} {BEGIN (STRING_START);insertEscStringBuffer(yytext);}
<STRING_ESCAPE>{VERTGAP} {BEGIN (STRING_START);lineCount++;insertStringBuffer("\\\n");}
<STRING_ESCAPE><<EOF>> {BEGIN (INITIAL);lineCount++;flushStringBuffer(UNTERMINATED_STRING);}
<STRING_ESCAPE>. {BEGIN(STRING_START);insertStringBuffer(yytext);}

<STRING_ERROR>[^\n\"]* {insertStringBuffer(yytext);}
<STRING_ERROR>{VERTGAP} {BEGIN (INITIAL);lineCount++;flushStringBuffer(UNRECOGNIZED_STRING);}
<STRING_ERROR>{DUOQUO} {BEGIN (INITIAL);flushStringBuffer(UNRECOGNIZED_STRING);}

<STRING_ERROR_ENTER>{VERTGAP} {BEGIN (STRING_ERROR); lineCount++;}
<STRING_ERROR_ENTER>. {BEGIN (STRING_ERROR);flushStringBuffer(UNRECOGNIZED_STRING);}

. {unrecognizedChar(yytext);return UNRECOGNIZED;}

%%