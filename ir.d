module ir;

import std.algorithm : any;
import parse, util;

// Intermediate representation

public:
enum IRType
{
    IMM,
    MOV,
    RETURN,
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

    size_t lhs;
    size_t rhs;
}

IR[] gen_ir(Node* node)
{
    assert(node.type == NodeType.COMP_STMT);
    size_t regno;
    return gen_stmt(regno, node);
}

private:

size_t gen_expr(ref IR[] ins, ref size_t regno, Node* node)
{
    if (node.type == NodeType.NUM)
    {
        size_t r = regno++;
        ins ~= IR(IRType.IMM, r, node.val);
        return r;
    }

    assert("+-*/".any!(v => cast(IRType) v == cast(IRType) node.type));

    size_t lhs = gen_expr(ins, regno, node.lhs);
    size_t rhs = gen_expr(ins, regno, node.rhs);

    ins ~= IR(cast(IRType) node.type, lhs, rhs);
    ins ~= IR(IRType.KILL, rhs, 0);
    return lhs;
}

IR[] gen_stmt(ref size_t regno, Node* node)
{
    IR[] res;
    if (node.type == NodeType.RETURN)
    {
        size_t r = gen_expr(res, regno, node.expr);
        res ~= IR(IRType.RETURN, r, 0);
        res ~= IR(IRType.KILL, r, 0);
        return res;
    }

    if (node.type == NodeType.EXPR_STMT)
    {
        size_t r = gen_expr(res, regno, node.expr);
        res ~= IR(IRType.KILL, r, 0);
        return res;
    }

    if (node.type == NodeType.COMP_STMT)
    {
        foreach (stmt; node.stmts)
        {
            res ~= gen_stmt(regno, &stmt);
        }
        return res;
    }

    error("unknown code: %s", node.type);
    assert(0);
}
