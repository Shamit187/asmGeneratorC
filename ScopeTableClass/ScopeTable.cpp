#include "ScopeTable.h"

ScopeTable::ScopeTable(unsigned int size, ScopeTable* parent, std::string id)
        : size{size},
          numberOfChild{0},
          parent{parent},
          hashTable{new SymbolInfo*[size]},
          id{id}
{
    for(int i = 0; i < size; i++)
        hashTable[i] = nullptr;
}

ScopeTable::~ScopeTable()
{
    SymbolInfo* currentChain;
    SymbolInfo* next;
    for(int i = 0; i < size; i++){
        currentChain = hashTable[i];
        while(currentChain!= nullptr){
            next = currentChain->getNext();
            delete currentChain;
            currentChain = next;
        }
    }
    delete[] this->hashTable;
}

bool ScopeTable::insert(std::string name, std::string type)
{
    SymbolInfo* symbolInfo = new SymbolInfo(name, type);
    unsigned int bucket = sdbmHash(name, size);

    SymbolInfo* current = hashTable[bucket];
    SymbolInfo* prev = nullptr;

    if(current == nullptr)

    {
        hashTable[bucket] = symbolInfo;
        return true;
    }
    else
    {
        while(current != nullptr){
            prev = current;
            current = prev->getNext();
            if(prev->getName() == name)
            {
                delete symbolInfo;
                return false;
            }
        }
        prev->setNext(symbolInfo);
    }
    return true;
}

bool ScopeTable::insert(std::string name, std::string type, std::vector<SymbolInfo> paramList)
{
    SymbolInfo* symbolInfo = new SymbolInfo(name, type, paramList);
    unsigned int bucket = sdbmHash(name, size);

    SymbolInfo* current = hashTable[bucket];
    SymbolInfo* prev = nullptr;

    if(current == nullptr)

    {
        hashTable[bucket] = symbolInfo;
        return true;
    }
    else
    {
        while(current != nullptr){
            prev = current;
            current = prev->getNext();
            if(prev->getName() == name)
            {
                delete symbolInfo;
                return false;
            }
        }
        prev->setNext(symbolInfo);
    }
    return true;
}

bool ScopeTable::insert(std::string name, std::string type, unsigned array_size)
{
    SymbolInfo* symbolInfo = new SymbolInfo(name, type, array_size);
    unsigned int bucket = sdbmHash(name, size);

    SymbolInfo* current = hashTable[bucket];
    SymbolInfo* prev = nullptr;

    if(current == nullptr)

    {
        hashTable[bucket] = symbolInfo;
        return true;
    }
    else
    {
        while(current != nullptr){
            prev = current;
            current = prev->getNext();
            if(prev->getName() == name)
            {
                delete symbolInfo;
                return false;
            }
        }
        prev->setNext(symbolInfo);
    }
    return true;
}

bool ScopeTable::remove(SymbolInfo* symbolInfo)
{
    if(symbolInfo == nullptr) return false;

    unsigned int bucket = sdbmHash(symbolInfo->getName(), size);

    SymbolInfo* current = hashTable[bucket];
    SymbolInfo* prev = nullptr;

    if(current == nullptr)
        return false;
    else if(current == symbolInfo)
    {
        hashTable[bucket] = current->getNext();
        delete current;
    }
    else{
        while(current != nullptr)
        {
            if(current == symbolInfo)
            {
                prev->setNext(current->getNext());
                delete current;
                return true;
            }
            prev = current;
            current = prev->getNext();
        }
    }
    return false;
}

SymbolInfo* ScopeTable::lookup(std::string name){

    unsigned int bucket = sdbmHash(name, size);

    SymbolInfo* current = hashTable[bucket];
    SymbolInfo* prev = nullptr;

    if(current == nullptr)
        return nullptr;
    else if(current->getName() == name)
        return current;
    else{
        while(current != nullptr)
        {
            if(current->getName() == name)
                return current;
            prev = current;
            current = prev->getNext();
        }
        return nullptr;
    }
}

std::string ScopeTable::getScopeId() const{
    return id;
}

void ScopeTable::print() const{
    std::cout << *this << std::endl;
}

std::ostream& operator<<(std::ostream& os, const ScopeTable& obj){
    os << "ScopeTable # " << obj.id << std::endl;

    for(int i = 0; i < obj.size; i++){
        os << i << " --> ";
        SymbolInfo* current = obj.hashTable[i];
        while(current != nullptr){
            os << *current << "  ";
            current = current->getNext();
        }
        if(i != obj.size - 1)
            os << std::endl;
    }

    return os;
}

std::string ScopeTable::toString() {
    std::string returnStatement = "";
    returnStatement += "ScopeTable # " + id + "\n";

    for(int i = 0; i < size; i++){
        if(hashTable[i]!= nullptr){
            returnStatement += std::to_string(i) + " --> ";
            SymbolInfo* current = hashTable[i];
            while(current != nullptr){
                returnStatement += current->toString() + "  ";
                current = current->getNext();
            }
            returnStatement += '\n';
        }
    }

    return returnStatement;
}

ScopeTable* ScopeTable::getParent(){
    return parent;
}

int ScopeTable::getChildAmount(){
    return numberOfChild;
}

void ScopeTable::incrementChild(){
    numberOfChild++;
}
