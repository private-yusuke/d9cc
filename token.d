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
    IDENT, // Identifier
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/',
    RETURN, // "return"
    SEMICOLONE = ';',
    ASSIGN = '=',
    EOF // End marker
}

struct Token
{
    TokenType type; // Token type
    int val; // Number literal
    string name; // Identifier
    string input; // Token string (for error reporting)

    // for debugging!
    string toString()
    {
        import std.string : format;
        import std.conv : to;

        switch (type)
        {
        case TokenType.NUM:
            return "%s %s".format(type, val);
        default:
            return type.to!string;
        }
    }
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
        if ("+-*/;=".canFind(s[i]))
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
            if (name in keywords)
            {
                Token t;
                t.type = keywords[name];
                t.input = name;
                res ~= t;
            }
            else
            {
                Token t;
                t.type = TokenType.IDENT;
                t.name = name;
                t.input = name;
                res ~= t;
            }

            i += len;
            continue;
        }

        error("cannot tokenize: %s", s);
    }

    res ~= Token(TokenType.EOF);
    return res;
}
