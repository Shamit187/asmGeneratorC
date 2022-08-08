#pragma once
#include "SymbolInfo.h"
#include "ScopeTable.h"
#include <iostream>

class SymbolTable
{
private:
    ScopeTable* current;
    ScopeTable* globalScope;
    int rootScopes;
    const unsigned int bucketSize;

public:
    SymbolTable(unsigned int bucketSize);
    ~SymbolTable();

    std::string enterScope();
    std::string exitScope();

    bool insert(std::string name, std::string type);
    bool insert(std::string name, std::string type, std::vector<SymbolInfo> paramList);
    bool insert(std::string name, std::string type, unsigned size);
    bool remove(std::string name);

    SymbolInfo* lookup(std::string name);
    SymbolInfo* lookGlobalScope(std::string name);
    SymbolInfo* lookCurrentScope(std::string name);

    bool isDefined(std::string name);
    void define(std::string name);

    std::string printCurrentScopeTable();
    std::string printAllScopeTable();

    friend std::ostream& operator<<(std::ostream& os, const SymbolTable& obj);
    std::string toString();

    std::string getCurrentScopeID(){return current->getScopeId();}
};

