#pragma once
#include <string>
#include <iostream>
#include <vector>

class SymbolInfo
{
private:
    std::string name;
    std::string type;
    SymbolInfo *next;

    std::vector<SymbolInfo> paramList;
    unsigned size;

    bool defined;

public:

    //regular
    SymbolInfo(std::string name, std::string type); 
    //function
    SymbolInfo(std::string name, std::string type, std::vector<SymbolInfo> paramList);
    //array
    SymbolInfo(std::string name, std::string type, unsigned size);

    ~SymbolInfo();

    //io operation
    std::string getName();
    std::string getType();
    SymbolInfo* getNext();
    std::vector<SymbolInfo> getParamList();
    unsigned getSize();

    void setName(std::string newName);
    void setType(std::string newType);
    void setNext(SymbolInfo* newNext);
    void pushParam(SymbolInfo symbolInfo);

    //util function
    std::string toString();
    friend std::ostream& operator<<(std::ostream& os, const SymbolInfo& obj);

    void define(){this->defined = true;}
    bool isDefined(){return this->defined;}
};

