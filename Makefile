build:
	gcc src/main.c -o dist/main src/cli.c src/frontend/lex.c src/frontend/parser.c src/frontend/codegen.c src/backend/x86_64.c -Wall -Wextra -Werror -std=c11 -pedantic -g

test-lex: build
	./writing-a-c-compiler-tests/test_compiler ./dist/main --chapter 1 --stage lex

test-parser: build
	./writing-a-c-compiler-tests/test_compiler ./dist/main --chapter 1 --stage parse

test-codegen: build
	./writing-a-c-compiler-tests/test_compiler ./dist/main --chapter 1 --stage codegen

test-chapter-1: build
	./writing-a-c-compiler-tests/test_compiler ./dist/main --chapter 1

build-zig:
	zig build-exe ./zig-rewrite/main.zig

test-lex-zig: build-zig
	./writing-a-c-compiler-tests/test_compiler ./main --chapter 1 --stage lex

test-parser-zig: build-zig
	./writing-a-c-compiler-tests/test_compiler ./main --chapter 1 --stage parse

test-codegen-zig: build-zig
	./writing-a-c-compiler-tests/test_compiler ./main --chapter 1 --stage codegen

test-chapter-1-zig: build-zig
	./writing-a-c-compiler-tests/test_compiler ./main --chapter 1