create:
	@yacc -Wyacc -y -d -Wno-yacc -Wcounterexamples parser.y
	@echo "6"

	@g++ -w -c -o y.o y.tab.c
	@echo "5"

	@flex scanner.l
	@echo "4"

	@g++ -w -c -o l.o lex.yy.c
	@echo "3"

	@g++ -w -c -o a.o ScopeTableClass/SymbolInfo.cpp
	@g++ -w -c -o b.o ScopeTableClass/ScopeTable.cpp
	@g++ -w -c -o c.o ScopeTableClass/SymbolTable.cpp
	@echo "2"

	@g++ -o compiler.out y.o l.o a.o b.o c.o -lfl
	@rm *.o y.tab.c y.tab.h lex.yy.c
	@echo "1"

	@./compiler.out input.txt
	@echo "0"

run:
	@./compiler.out input.txt
	@echo "0"

delete:
	@rm *.out
	@echo "0"

