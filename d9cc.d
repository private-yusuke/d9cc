import std.stdio : writeln, writefln, stderr;
import std.conv : to;
import std.uni : isSpace;
import std.ascii : isDigit;
import std.array : join;

enum TokenType
{
    NUM, // Number literal
    ADD = '+',
    SUB = '-',
    EOF // end literal
}

struct Token
{
    TokenType type;
    int val;
    string input;
}

class QuitException : Exception
{
    int return_code;

    this(int return_code = 0, string file = __FILE__, size_t line = __LINE__)
    {
        super(null, file, line);
        this.return_code = return_code;
    }
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
        if (s[i] == '+' || s[i] == '-')
        {
            Token t;
            t.type = s[i].to!TokenType;
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

void fail(Token t)
{
    stderr.writefln("Unexpected token: %s", t.input);
    throw new QuitException(-1);
}

int main(string[] args)
{
    if (args.length < 2)
    {
        stderr.writeln("Usage: d9cc <code>");
        return 1;
    }

    try
    {
        auto tokens = tokenize(args[1]);
        writeln(".intel_syntax noprefix");
        writeln(".global main");
        writeln("main:");

        if (tokens[0].type != TokenType.NUM)
            fail(tokens[0]);
        writefln("  mov rax, %d", tokens[0].val);

        size_t i = 1;
        while (tokens[i].type != TokenType.EOF)
        {
            if (tokens[i].type == '+')
            {
                i++;
                if (tokens[i].type != TokenType.NUM)
                    fail(tokens[i]);
                writefln("  add rax, %d", tokens[i].val);
                i++;
                continue;
            }
            if (tokens[i].type == '-')
            {
                i++;
                if (tokens[i].type != TokenType.NUM)
                    fail(tokens[i]);
                writefln("  sub rax, %d", tokens[i].val);
                i++;
                continue;
            }

            fail(tokens[i]);
        }
        writeln("  ret");
    }
    catch (QuitException e)
        return e.return_code;
    return 0;
}

int nextInt(string s, ref size_t i)
{
    int res;
    while (i < s.length && '0' <= s[i] && s[i] <= '9')
    {
        res = (res * 10) + (s[i] - '0');
        i++;
    }
    return res;
}
