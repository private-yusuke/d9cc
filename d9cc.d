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

// Intermediate representation

enum IRType
{
    IMM,
    MOV,
    RETURN,
    KILL,
    NOP,
    ADD = '+',
    SUB = '-'
}

struct IR
{
    IRType type;
    size_t lhs;
    size_t rhs;
}

IR new_ir(IRType type, size_t lhs, size_t rhs)
{
    IR ir;
    ir.type = type;
    ir.lhs = lhs;
    ir.rhs = rhs;
    return ir;
}

size_t gen_ir_sub(ref IR[] ins, ref size_t regno, Node* node)
{
    if (node.type == NodeType.NUM)
    {
        size_t r = regno++;
        ins ~= new_ir(IRType.IMM, r, node.val);
        return r;
    }

    assert(node.type == '+' || node.type == '-');

    size_t lhs = gen_ir_sub(ins, regno, node.lhs);
    size_t rhs = gen_ir_sub(ins, regno, node.rhs);

    ins ~= new_ir(cast(IRType) node.type, lhs, rhs);
    ins ~= new_ir(IRType.KILL, rhs, 0);
    return lhs;
}

IR[] gen_ir(Node* node)
{
    IR[] res;
    size_t regno;

    size_t r = gen_ir_sub(res, regno, node);
    res ~= new_ir(IRType.RETURN, r, 0);
    return res;
}

static immutable string[] regs = [
    "rdi", "rsi", "r10", "r11", "r12", "r13", "r14", "r15"
];

size_t alloc(ref size_t[size_t] reg_map, ref bool[] used, size_t ir_reg)
{
    if (ir_reg in reg_map)
    {
        size_t r = reg_map[ir_reg];
        assert(used[r]);
        return r;
    }

    foreach (i; 0 .. regs.length)
    {
        if (used[i])
            continue;
        used[i] = true;
        reg_map[ir_reg] = i;
        return i;
    }
    stderr.writeln("register exhausted");
    throw new QuitException(-1);
}

void kill(ref bool[] used, size_t r)
{
    assert(used[r]);
    used[r] = false;
}

void alloc_regs(ref IR[] ins)
{
    size_t[size_t] reg_map;
    bool[] used = new bool[](regs.length);

    foreach (ref ir; ins)
    {
        switch (ir.type)
        {
        case IRType.IMM:
            ir.lhs = alloc(reg_map, used, ir.lhs);
            break;
        case IRType.MOV:
        case IRType.ADD:
        case IRType.SUB:
            ir.lhs = alloc(reg_map, used, ir.lhs);
            ir.rhs = alloc(reg_map, used, ir.rhs);
            break;
        case IRType.RETURN:
            kill(used, reg_map[ir.lhs]);
            break;
        case IRType.KILL:
            kill(used, reg_map[ir.lhs]);
            ir.type = IRType.NOP;
            break;
        default:
            assert(0, "unknown operator");
        }
    }
}

// Code generator

void gen_x86(IR[] ins)
{
    foreach (ir; ins)
    {
        switch (ir.type)
        {
        case IRType.IMM:
            writefln("  mov %s, %d", regs[ir.lhs], ir.rhs);
            break;
        case IRType.MOV:
            writefln("  mov %s, %s", regs[ir.lhs], regs[ir.rhs]);
            break;
        case IRType.RETURN:
            writefln("  mov rax, %s", regs[ir.lhs]);
            writeln("  ret");
            break;
        case IRType.ADD:
            writefln("  add %s, %s", regs[ir.lhs], regs[ir.rhs]);
            break;
        case IRType.SUB:
            writefln("  sub %s, %s", regs[ir.lhs], regs[ir.rhs]);
            break;
        case IRType.NOP:
            break;
        default:
            assert(0, "unknown operator");
        }
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
        Token[] tokens = tokenize(args[1]);
        Node* node = expr(tokens);

        IR[] ins = gen_ir(node);
        alloc_regs(ins);

        writeln(".intel_syntax noprefix");
        writeln(".global main");
        writeln("main:");

        gen_x86(ins);
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
