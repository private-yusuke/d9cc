module ir;

import std.algorithm : any;
import parse, util;

// Intermediate representation

public:
enum IRType
{
    IMM,
    ADD_IMM,
    MOV,
    RETURN,
    ALLOCA,
    LOAD,
    STORE,
    KILL,
    NOP,
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/'
}

struct IR
{
    IRType type;

    long lhs;
    long rhs;

    string toString()
    {
        import std.string : format;
        import std.conv : to;

        switch (type)
        {
        case IRType.IMM:
            return "IMM %s %s".format(lhs, rhs);
        default:
            return type.to!string;
        }
    }
}

IR[] gen_ir(Node* node)
{
    assert(node.type == NodeType.COMP_STMT);

    IR[] res;
    res ~= IR(IRType.ALLOCA, basereg, 0);
    res ~= gen_stmt(node);
    res[0].rhs = bpoff;
    return res;
}

private:

long regno = 1;
long basereg;
long bpoff;
long[string] vars;

long gen_lval(ref IR[] ins, Node* node)
{
    if (node.type != NodeType.IDENT)
        error("not an lvalue");

    if (node.name !in vars)
    {
        vars[node.name] = bpoff;
        bpoff += 8;
    }
    long r = regno++;
    long off = vars[node.name];
    ins ~= IR(IRType.MOV, r, basereg);
    ins ~= IR(IRType.ADD_IMM, r, off);
    return r;
}

long gen_expr(ref IR[] ins, Node* node)
{
    if (node.type == NodeType.NUM)
    {
        long r = regno++;
        ins ~= IR(IRType.IMM, r, node.val);
        return r;
    }

    if (node.type == NodeType.IDENT)
    {
        long r = gen_lval(ins, node);
        ins ~= IR(IRType.LOAD, r, r);
        return r;
    }

    if (node.type == NodeType.ASSIGN)
    {
        long rhs = gen_expr(ins, node.rhs);
        long lhs = gen_lval(ins, node.lhs);
        ins ~= IR(IRType.STORE, lhs, rhs);
        ins ~= IR(IRType.KILL, rhs, -1);

        return lhs;
    }

    assert("+-*/".any!(v => cast(IRType) v == cast(IRType) node.type));

    long lhs = gen_expr(ins, node.lhs);
    long rhs = gen_expr(ins, node.rhs);

    ins ~= IR(cast(IRType) node.type, lhs, rhs);
    ins ~= IR(IRType.KILL, rhs, -1);
    return lhs;
}

IR[] gen_stmt(Node* node)
{
    IR[] res;
    if (node.type == NodeType.RETURN)
    {
        long r = gen_expr(res, node.expr);
        res ~= IR(IRType.RETURN, r, -1);
        res ~= IR(IRType.KILL, r, -1);
        return res;
    }

    if (node.type == NodeType.EXPR_STMT)
    {
        long r = gen_expr(res, node.expr);
        res ~= IR(IRType.KILL, r, -1);
        return res;
    }

    if (node.type == NodeType.COMP_STMT)
    {
        foreach (stmt; node.stmts)
        {
            res ~= gen_stmt(&stmt);
        }
        return res;
    }

    error("unknown code: %s", node.type);
    assert(0);
}
