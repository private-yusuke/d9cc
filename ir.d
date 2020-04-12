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
    CALL,
    LABEL,
    JMP,
    UNLESS,
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

enum IRInfo
{
    NOARG,
    REG,
    LABEL,
    REG_REG,
    REG_IMM,
    REG_LABEL,
    CALL
}

struct IR
{
    IRType type;
    long lhs;
    long rhs;

    // Function call
    string name;
    long nargs;
    long[] args;

    IRInfo getInfo()
    {
        switch (type)
        {
        case IRType.ADD:
        case IRType.SUB:
        case IRType.MUL:
        case IRType.DIV:
        case IRType.MOV:
        case IRType.LOAD:
        case IRType.STORE:
            return IRInfo.REG_REG;
        case IRType.IMM:
        case IRType.ADD_IMM:
        case IRType.ALLOCA:
            return IRInfo.REG_IMM;
        case IRType.LABEL:
        case IRType.JMP:
            return IRInfo.LABEL;
        case IRType.UNLESS:
            return IRInfo.REG_LABEL;
        case IRType.CALL:
            return IRInfo.CALL;
        case IRType.RETURN:
        case IRType.KILL:
            return IRInfo.REG;
        case IRType.NOP:
            return IRInfo.NOARG;
        default:
            assert(0);
        }
    }

    string toString()
    {
        import std.string : format;
        import std.conv : to;

        switch (this.getInfo())
        {
        case IRInfo.LABEL:
            return format("%s:", this.lhs);
        case IRInfo.REG:
            return format("%s r%d", this.type, this.lhs);
        case IRInfo.REG_REG:
            return format("%s r%d, r%d", this.type, this.lhs, this.rhs);
        case IRInfo.REG_IMM:
            return format("%s r%d, %d", this.type, this.lhs, this.rhs);
        case IRInfo.REG_LABEL:
            return format("%s r%d, .L%s", this.type, this.lhs, this.rhs);
        case IRInfo.CALL:
            return format("r%d = %s(%(r%d, %)", this.name, this.lhs);
        case IRInfo.NOARG:
            return this.type.to!string;
        default:
            assert(0);
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
long label;
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

    if (node.type == NodeType.CALL)
    {
        IR ir;
        ir.type = IRType.CALL;
        foreach (arg; node.args)
            ir.args ~= gen_expr(ins, &arg);

        long r = regno++;
        ir.lhs = r;
        ir.name = node.name;
        ins ~= ir;
        foreach (v; ir.args)
            ins ~= IR(IRType.KILL, v, -1);
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

    if (node.type == NodeType.IF)
    {
        long r = gen_expr(res, node.cond);
        long x = label++;

        res ~= IR(IRType.UNLESS, r, x);
        res ~= IR(IRType.KILL, r, -1);

        res ~= gen_stmt(node.then);

        if (!node.els)
        {
            res ~= IR(IRType.LABEL, x, -1);
            return res;
        }

        long y = label++;
        res ~= IR(IRType.JMP, y, -1);
        res ~= IR(IRType.LABEL, x, -1);
        res ~= gen_stmt(node.els);
        res ~= IR(IRType.LABEL, y, -1);
        return res;
    }

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
            res ~= gen_stmt(stmt);
        }
        return res;
    }

    error("unknown code: %s", node.type);
    assert(0);
}
