import std.stdio : writeln, writefln, stderr;
import std.conv : to;
import std.uni : isSpace;
import std.ascii : isDigit;
import std.array : join;

// Tokenizer

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

class QuitException : Exception
{
    int return_code;

    this(int return_code = 0, string file = __FILE__, size_t line = __LINE__)
    {
        super(null, file, line);
        this.return_code = return_code;
    }
}

void fail(Token t)
{
    stderr.writefln("Unexpected token: %s", t.input);
    throw new QuitException(-1);
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

enum NodeType
{
    NUM, // Number literal
    ADD = '+',
    SUB = '-'
}

struct Node
{
    NodeType type; // Node type
    Node* lhs = null;
    Node* rhs = null;
    int val; // Number literal
}

Node* new_node(NodeType op, Node* lhs, Node* rhs)
{
    Node* node = new Node;
    node.type = op;
    node.lhs = lhs;
    node.rhs = rhs;
    return node;
}

Node* new_node_num(int val)
{
    Node* node = new Node;
    node.type = NodeType.NUM;
    node.val = val;
    return node;
}

Node* number(Token[] tokens, ref size_t pos)
{
    if (tokens[pos].type == TokenType.NUM)
        return new_node_num(tokens[pos++].val);
    stderr.writefln("Number expected, but got %s", tokens[pos].input);
    throw new QuitException(-1);
}

Node* expr(Token[] tokens)
{
    size_t pos;
    Node* lhs = number(tokens, pos);
    while (true)
    {
        TokenType op = tokens[pos].type;
        if (op != '+' && op != '-')
            break;
        pos++;
        lhs = new_node(cast(NodeType) op, lhs, number(tokens, pos));
    }

    if (tokens[pos].type != TokenType.EOF)
        stderr.writefln("stray token: %s", tokens[pos].input);
    return lhs;
}

// Code Generator

string[] regs = ["rdi", "rsi", "r10", "r11", "r12", "r13", "r14", "r15"];

string gen(Node* node, ref size_t cur)
{
    if (node.type == NodeType.NUM)
    {
        if (cur + 1 > regs.length)
        {
            stderr.writeln("register exhausted");
            throw new QuitException(-1);
        }
        string reg = regs[cur++];
        writefln("  mov %s, %d", reg, node.val);
        return reg;
    }

    string dst = gen(node.lhs, cur);
    string src = gen(node.rhs, cur);

    switch (node.type)
    {
    case NodeType.ADD:
        writefln("  add %s, %s", dst, src);
        return dst;
    case NodeType.SUB:
        writefln("  sub %s, %s", dst, src);
        return dst;
    default:
        stderr.writeln("unknown operator");
        throw new QuitException(-1);
    }
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
        size_t cur;
        auto tokens = tokenize(args[1]);
        Node* node = expr(tokens);
        writeln(".intel_syntax noprefix");
        writeln(".global main");
        writeln("main:");

        // generate code while descending the parse tree.
        writefln("  mov rax, %s", gen(node, cur));
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
