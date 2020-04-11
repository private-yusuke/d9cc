module token;

import std.stdio : stderr;
import std.uni : isSpace;
import std.ascii : isDigit, isAlpha;
import std.algorithm : canFind;

import util;

// Tokenizer

public:

enum TokenType
{
    NUM, // Number literal
    ADD = '+',
    SUB = '-',
    RETURN, // "return"
    SEMICOLONE = ';',
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
    TokenType[string] keywords;
    keywords["return"] = TokenType.RETURN;

    while (i < s.length)
    {
        if (s[i].isSpace)
        {
            i++;
            continue;
        }
        if ("+-*/;".canFind(s[i]))
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

        // Keyword
        if (isAlpha(s[i]) || s[i] == '_')
        {
            size_t len = 1;
            while (isAlpha(s[i + len]) || isDigit(s[i + len]) || s[i + len] == '_')
                len++;

            string name = s[i .. i + len];
            if (name !in keywords)
                error("unknown identifier: %s", name);

            res ~= Token(keywords[name], 0, name);
            i += len;
            continue;
        }

        error("cannot tokenize: %s", s);
    }

    Token t;
    t.type = TokenType.EOF;
    res ~= t;
    return res;
}
