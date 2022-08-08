#pragma once
#include "SymbolInfo.h"
#include <iostream>

class ScopeTable
{
private:
    const unsigned int size;
    unsigned int numberOfChild;
    ScopeTable* parent;
    SymbolInfo** hashTable;

    std::string id;

    /*
        static declaration of sdbm hashfunction
        taken from http://www.cse.yorku.ca/~oz/hash.html
    */
    static unsigned int sdbmHash(const std::string& str, int mod){
        unsigned long hash = 0;
        int c;

        for(int i = 0; i < str.length(); i++){
            c = (int) str.at(i);
            hash = c + (hash << 6) + (hash << 16) - hash;
        }

        return hash % mod;
    }

public:
    ScopeTable(unsigned int size, ScopeTable* parent, std::string id);
    ~ScopeTable();

    //io operation
    bool insert(std::string name, std::string type);
    bool insert(std::string name, std::string type, std::vector<SymbolInfo> paramList);
    bool insert(std::string name, std::string type, unsigned size);
    /* if symbol info expands, add to parameter */
    bool remove(SymbolInfo* symbolInfo);
    SymbolInfo* lookup(std::string name);
    ScopeTable* getParent();
    int getChildAmount();

    //modifications
    void incrementChild();

    //util function
    void print() const;
    friend std::ostream& operator<<(std::ostream& os, const ScopeTable& obj);
    std::string getScopeId() const;
    std::string toString();
};



