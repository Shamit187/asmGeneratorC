#include "SymbolTable.h"

SymbolTable::SymbolTable(unsigned int bucketSize)
        :current{nullptr},
         globalScope{nullptr},
         rootScopes{0},
         bucketSize{bucketSize}
{
    enterScope();
    globalScope = current;
}

SymbolTable::~SymbolTable()
{
    ScopeTable* next = nullptr;
    while (current != nullptr)
    {
        next = current->getParent();
        delete current;
        current = next;
    }

}

std::string SymbolTable::enterScope(){
    if(current == nullptr){
        rootScopes++;
        ScopeTable* newScopeTable = new ScopeTable( bucketSize,
                                                    nullptr,
                                                    std::to_string(rootScopes));
        current = newScopeTable;
    }
    else{
        current->incrementChild();
        ScopeTable* newScopeTable = new ScopeTable( bucketSize,
                                                    current,
                                                    current->getScopeId()
                                                    + "."
                                                    + std::to_string(current->getChildAmount()));
        current = newScopeTable;
    }
    return
        "New ScopeTable with id "
        + current->getScopeId() + " created";
}

std::string SymbolTable::exitScope(){
    if(current == nullptr) return "No Scope in Existence";
    else{
        std::string id = current->getScopeId();
        ScopeTable* rem = current->getParent();
        delete current;
        current = rem;
        return "ScopeTable with id " + id + " removed";
    }
}

bool SymbolTable::insert(std::string name, std::string type){
    if(current == nullptr){
        enterScope();
        globalScope = current;
    }
    return current->insert(name, type);
}

bool SymbolTable::insert(std::string name, std::string type, std::vector<SymbolInfo> paramList){
    if(current == nullptr){
        enterScope();
        globalScope = current;
    }
    return current->insert(name, type, paramList);
}

bool SymbolTable::insert(std::string name, std::string type, unsigned array_size){
    if(current == nullptr){
        enterScope();
        globalScope = current;
    }
    return current->insert(name, type, array_size);
}

bool SymbolTable::remove(std::string name){
    if(current == nullptr) return false;
    return current->remove(current->lookup(name));
}

SymbolInfo* SymbolTable::lookup(std::string name){
    ScopeTable* it = current;
    SymbolInfo* returnPtr = nullptr;
    while(it != nullptr){
        returnPtr = it->lookup(name);
        if(returnPtr != nullptr)
            return returnPtr;
        it = it->getParent();
    }
    return nullptr;
}

SymbolInfo* SymbolTable::lookGlobalScope(std::string name){
    ScopeTable* it = globalScope;
    if(it == nullptr) return nullptr;
    return it->lookup(name);
}

SymbolInfo* SymbolTable::lookCurrentScope(std::string name){
    ScopeTable* it = current;
    if(it == nullptr) return nullptr;
    return it->lookup(name);
}

std::string SymbolTable::printCurrentScopeTable(){
    if(current == nullptr) return "No scope active";
    else return current->toString();
}

std::string SymbolTable::printAllScopeTable(){
    return toString();
}

std::ostream& operator<<(std::ostream& os, const SymbolTable& obj){
    if(obj.current == nullptr) return os;
    ScopeTable* it = obj.current;
    while(it != nullptr){
        os << *it <<  std::endl;
        it = it->getParent();
    }
    return os;
}

std::string SymbolTable::toString() {
    if(current == nullptr) return "No Scope in Existence";
    std::string returnStatement;
    ScopeTable* it = current;
    while(it != nullptr){
        returnStatement += it->toString() + '\n';
        it = it->getParent();
    }
    return returnStatement;
}

bool SymbolTable::isDefined(std::string name){
    return (this->lookGlobalScope(name))->isDefined();
}

void SymbolTable::define(std::string name){
    (this->lookGlobalScope(name))->define();
}