#include "SymbolInfo.h"


SymbolInfo::SymbolInfo(std::string name,
                       std::string type)
        :name{name},
         type{type},
         size{0},
         next{nullptr},
         defined{false},
         asmCode{""}
{}

SymbolInfo::SymbolInfo(std::string name,
                       std::string type,
                       std::string asmCode)
        :name{name},
         type{type},
         size{0},
         next{nullptr},
         defined{false},
         asmCode{asmCode}
{}

SymbolInfo::SymbolInfo(std::string name,
                       std::string type,
                       std::vector<SymbolInfo> paramList)
        :name{name},
         type{type},
         paramList{paramList},
         size{0},
         next{nullptr},
         defined{false},
         asmCode{""}
{}

SymbolInfo::SymbolInfo(std::string name,
                       std::string type,
                       unsigned size,
                       std::string asmCode)
        :name{name},
         type{type},
         size{size},
         next{nullptr},
         defined{false},
         asmCode{asmCode}
{}

SymbolInfo::~SymbolInfo()
{}

std::string SymbolInfo::getName(){return name;}

std::string SymbolInfo::getType(){return type;}

SymbolInfo* SymbolInfo::getNext(){return next;}

std::vector<SymbolInfo> SymbolInfo::getParamList(){return paramList;}

unsigned SymbolInfo::getSize(){return size;}

std::string SymbolInfo::getAsm(){return asmCode;}

void SymbolInfo::setName(std::string newName){this->name = newName;}

void SymbolInfo::setType(std::string newType){this->type = newType;}

void SymbolInfo::setNext(SymbolInfo* newNext){this->next = newNext;}

void SymbolInfo::pushParam(SymbolInfo symbolInfo){(this->paramList).push_back(symbolInfo);}

void SymbolInfo::setAsm(std::string asmCode){this->asmCode = asmCode;}

std::ostream& operator<<(std::ostream& os, const SymbolInfo& obj){
    os << "< " << obj.name << " : " << obj.type << " >";
    return os;
}

std::string SymbolInfo::toString() {
    std::string returnStatement;
    if(type == "FUNC_INT" || type == "FUNC_FLOAT" || type == "FUNC_VOID")
    {
        returnStatement =  "< " + name + " : " + type;
        if(defined) returnStatement += " (defined) >";
        else returnStatement += " (declared) >";
    }
    else if(type == "ARRAY_INT" || type == "ARRAY_FLOAT" || type == "ARRAY_VOID")
    {
        returnStatement =  "< " + name + " : " + type + " (size: " + std::to_string(size) + ") >";
    }
    else
        returnStatement =  "< " + name + " : " + type + " >";
    
    return returnStatement;
}
