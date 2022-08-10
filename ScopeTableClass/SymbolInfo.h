#pragma once
#include <string>
#include <iostream>
#include <vector>

class SymbolInfo
{
private:
    std::string name;
    std::string type;
    std::string asmCode;
    SymbolInfo *next;

    std::vector<SymbolInfo> paramList;
    unsigned size;

    bool defined;

public:

    //regular
    SymbolInfo(std::string name, std::string type);
    //rid
    SymbolInfo(std::string name, std::string type, std::string asmCode); 
    //function
    SymbolInfo(std::string name, std::string type, std::vector<SymbolInfo> paramList, std::string asmCode);
    //array
    SymbolInfo(std::string name, std::string type, unsigned size, std::string asmCode);

    ~SymbolInfo();

    //io operation
    std::string getName();
    std::string getType();
    SymbolInfo* getNext();
    std::vector<SymbolInfo> getParamList();
    unsigned getSize();
    std::string getAsm();

    void setName(std::string newName);
    void setType(std::string newType);
    void setNext(SymbolInfo* newNext);
    void pushParam(SymbolInfo symbolInfo);
    void setAsm(std::string asmCode);

    //util function
    std::string toString();
    friend std::ostream& operator<<(std::ostream& os, const SymbolInfo& obj);

    void define(){this->defined = true;}
    bool isDefined(){return this->defined;}
};

