module token;

import std.stdio : stderr;
import std.uni : isSpace;
import std.ascii : isDigit;
import std.algorithm : canFind;

import util;

// Tokenizer

public:

enum TokenType
{
    NUM, // Number literal
    ADD = '+',
    SUB = '-',
    EOF // End marker
}

struct Token
{
    TokenType type; // Token type
    int val; // Number literal
    string input; // Token string (for error reporting)
}

Token[] tokenize(string s)
{
    Token[] res;
    size_t i;

    while (i < s.length)
    {
        if (s[i].isSpace)
        {
            i++;
            continue;
        }
        if ("+-*".canFind(s[i]))
        {
            Token t;
            t.type = cast(TokenType) s[i];
            t.input = s[i .. i + 1];

            res ~= t;
            i++;
            continue;
        }
        if (s[i].isDigit)
        {
            Token t;
            t.type = TokenType.NUM;
            size_t _i = i;
            t.val = nextInt(s, i);
            t.input = s[_i .. i];

            res ~= t;
            continue;
        }

        stderr.writefln("cannot tokenize: %s", s);
        throw new QuitException(1);
    }

    Token t;
    t.type = TokenType.EOF;
    res ~= t;
    return res;
}
