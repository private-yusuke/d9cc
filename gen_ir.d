module gen_ir;

import std.algorithm : any;
import std.stdio : stderr;
import parse, util;
import sema : size_of;

// Intermediate representation

public:
enum IRType
{
    IMM,
    SUB_IMM,
    MOV,
    RETURN,
    CALL,
    LABEL,
    LT,
    JMP,
    UNLESS,
    LOAD,
    STORE,
    KILL,
    SAVE_ARGS,
    NOP,
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/'
}

// Compile AST to intermediate code that has infinite number of registers.
// Base pointer is always assigned to r0.

enum IRInfo
{
    NOARG,
    REG,
    IMM,
    LABEL,
    REG_REG,
    REG_IMM,
    REG_LABEL,
    CALL,
    JMP
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
        case IRType.LT:
            return IRInfo.REG_REG;
        case IRType.IMM:
        case IRType.SUB_IMM:
            return IRInfo.REG_IMM;
        case IRType.LABEL:
            return IRInfo.LABEL;
        case IRType.JMP:
            return IRInfo.JMP;
        case IRType.UNLESS:
            return IRInfo.REG_LABEL;
        case IRType.CALL:
            return IRInfo.CALL;
        case IRType.RETURN:
        case IRType.KILL:
            return IRInfo.REG;
        case IRType.SAVE_ARGS:
            return IRInfo.IMM;
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
        case IRInfo.IMM:
            return format("  %s %d", this.type, this.lhs);
        case IRInfo.REG:
            return format("  %s r%d", this.type, this.lhs);
        case IRInfo.REG_REG:
            return format("  %s r%d, r%d", this.type, this.lhs, this.rhs);
        case IRInfo.REG_IMM:
            return format("  %s r%d, %d", this.type, this.lhs, this.rhs);
        case IRInfo.JMP:
            return format("  %s .L%d", this.type, this.lhs);
        case IRInfo.REG_LABEL:
            return format("  %s r%d, .L%s", this.type, this.lhs, this.rhs);
        case IRInfo.CALL:
            return format("  r%s = %s(%(r%s, %))", this.rhs, this.name, this.args);
        case IRInfo.NOARG:
            return format("  %s", this.type.to!string);
        default:
            assert(0);
        }
    }
}

struct Function
{
    string name;
    long stacksize;
    IR[] ir;
}

Function[] gen_ir(Node[] nodes)
{
    Function[] res;
    foreach (n; nodes)
    {
        assert(n.op == NodeType.FUNC);

        IR[] code;
        regno = 1; // 0 for the base register

        if (nodes.length > 0)
            code ~= IR(IRType.SAVE_ARGS, n.args.length);
        code ~= gen_stmt(n.fbody);

        Function fn;
        fn.name = n.name;
        fn.stacksize = n.stacksize;
        fn.ir = code;
        res ~= fn;
    }
    return res;
}

void dump_ir(Function[] irv)
{
    foreach (fn; irv)
    {
        stderr.writefln("%s():", fn.name);
        foreach (ir; fn.ir)
            stderr.writefln("  %s", ir);
    }
}

private:

long regno;
long label;

long gen_lval(ref IR[] ins, Node* node)
{
    if (node.op != NodeType.LVAR)
        error("not an lvalue: %s (%s)", node.op, node.name);

    long r = regno++;
    ins ~= IR(IRType.MOV, r, 0);
    ins ~= IR(IRType.SUB_IMM, r, node.offset);
    return r;
}

long gen_binop(ref IR[] ins, IRType ty, Node* lhs, Node* rhs)
{
    long r1 = gen_expr(ins, lhs);
    long r2 = gen_expr(ins, rhs);
    ins ~= IR(ty, r1, r2);
    ins ~= IR(IRType.KILL, r2, -1);
    return r1;
}

long gen_expr(ref IR[] ins, Node* node)
{
    switch (node.op)
    {
    case NodeType.NUM:
        long r = regno++;
        ins ~= IR(IRType.IMM, r, node.val);
        return r;
    case NodeType.LOGAND:
        long x = label++;

        long r1 = gen_expr(ins, node.lhs);
        ins ~= IR(IRType.UNLESS, r1, x);
        long r2 = gen_expr(ins, node.rhs);
        ins ~= IR(IRType.MOV, r1, r2);
        ins ~= IR(IRType.KILL, r2, -1);
        ins ~= IR(IRType.UNLESS, r1, x);
        ins ~= IR(IRType.IMM, r1, 1);
        ins ~= IR(IRType.LABEL, x, -1);
        return r1;
    case NodeType.LOGOR:
        long x = label++;
        long y = label++;

        long r1 = gen_expr(ins, node.lhs);
        ins ~= IR(IRType.UNLESS, r1, x);
        ins ~= IR(IRType.IMM, r1, 1);
        ins ~= IR(IRType.JMP, y, -1);
        ins ~= IR(IRType.LABEL, x, -1);

        long r2 = gen_expr(ins, node.rhs);
        ins ~= IR(IRType.MOV, r1, r2);
        ins ~= IR(IRType.KILL, r2, -1);
        ins ~= IR(IRType.UNLESS, r1, y);
        ins ~= IR(IRType.IMM, r1, 1);
        ins ~= IR(IRType.LABEL, y, -1);
        return r1;

    case NodeType.LVAR:
        long r = gen_lval(ins, node);
        ins ~= IR(IRType.LOAD, r, r);
        return r;
    case NodeType.CALL:
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
    case NodeType.DEREF:
        long r = gen_expr(ins, node.expr);
        ins ~= IR(IRType.LOAD, r, r);
        return r;
    case NodeType.ASSIGN:
        long rhs = gen_expr(ins, node.rhs);
        long lhs = gen_lval(ins, node.lhs);
        ins ~= IR(IRType.STORE, lhs, rhs);
        ins ~= IR(IRType.KILL, rhs, -1);

        return lhs;
    case NodeType.ADD:
    case NodeType.SUB:
        IRType insn = (node.op == NodeType.ADD)
            ? IRType.ADD : IRType.SUB;

        if (node.lhs.type.type != TypeName.PTR)
            return gen_binop(ins, insn, node.lhs, node.rhs);

        long rhs = gen_expr(ins, node.rhs);
        long r = regno++;
        ins ~= IR(IRType.IMM, r, size_of(*(node.lhs.type.ptr_of)));
        ins ~= IR(IRType.MUL, rhs, r);
        ins ~= IR(IRType.KILL, r);

        long lhs = gen_expr(ins, node.lhs);
        ins ~= IR(insn, lhs, rhs);
        ins ~= IR(IRType.KILL, rhs);
        return lhs;
    case NodeType.MUL:
        return gen_binop(ins, IRType.MUL, node.lhs, node.rhs);
    case NodeType.DIV:
        return gen_binop(ins, IRType.DIV, node.lhs, node.rhs);
    case NodeType.LESS_THAN:
        return gen_binop(ins, IRType.LT, node.lhs, node.rhs);
    default:
        error("unknown AST type: %s", node.op);
        assert(0);
    }
}

IR[] gen_stmt(Node* node)
{
    IR[] res;

    if (node.op == NodeType.VARDEF)
    {

        if (!node.initialize)
            return res;

        long rhs = gen_expr(res, node.initialize);
        long lhs = regno++;

        res ~= IR(IRType.MOV, lhs, 0);
        res ~= IR(IRType.SUB_IMM, lhs, node.offset);
        res ~= IR(IRType.STORE, lhs, rhs);
        res ~= IR(IRType.KILL, lhs, -1);
        res ~= IR(IRType.KILL, rhs, -1);
        return res;
    }

    if (node.op == NodeType.IF)
    {
        if (node.els)
        {
            long x = label++;
            long y = label++;
            long r = gen_expr(res, node.cond);

            res ~= IR(IRType.UNLESS, r, x);
            res ~= IR(IRType.KILL, r, -1);

            res ~= gen_stmt(node.then);
            res ~= IR(IRType.JMP, y, -1);
            res ~= IR(IRType.LABEL, x, -1);
            res ~= gen_stmt(node.els);
            res ~= IR(IRType.LABEL, y, -1);
        }

        long x = label++;
        long r = gen_expr(res, node.cond);

        res ~= IR(IRType.UNLESS, r, x);
        res ~= IR(IRType.KILL, r, -1);

        res ~= gen_stmt(node.then);

        res ~= IR(IRType.LABEL, x, -1);

        return res;
    }

    if (node.op == NodeType.FOR)
    {
        long x = label++;
        long y = label++;

        res ~= gen_stmt(node.initialize);
        res ~= IR(IRType.LABEL, x, -1);
        long r = gen_expr(res, node.cond);
        res ~= IR(IRType.UNLESS, r, y);
        res ~= IR(IRType.KILL, r, -1);
        res ~= gen_stmt(node.fbody);
        res ~= IR(IRType.KILL, gen_expr(res, node.inc), -1);
        res ~= IR(IRType.JMP, x, -1);
        res ~= IR(IRType.LABEL, y, -1);
        return res;
    }

    if (node.op == NodeType.RETURN)
    {
        long r = gen_expr(res, node.expr);
        res ~= IR(IRType.RETURN, r, -1);
        res ~= IR(IRType.KILL, r, -1);
        return res;
    }

    if (node.op == NodeType.EXPR_STMT)
    {
        long r = gen_expr(res, node.expr);
        res ~= IR(IRType.KILL, r, -1);
        return res;
    }

    if (node.op == NodeType.COMP_STMT)
    {
        foreach (stmt; node.stmts)
        {
            res ~= gen_stmt(stmt);
        }
        return res;
    }

    error("unknown code: %s", node.op);
    assert(0);
}
