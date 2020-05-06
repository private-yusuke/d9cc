module sema;

import parse : Node, NodeType, Type, TypeName;
import util;
import std.algorithm : swap;

public:
void sema(ref Node[] nodes)
{
    foreach (node; nodes)
    {
        assert(node.op == NodeType.FUNC);

        vars.clear();
        stacksize = 0;
        walk(&node);
        node.stacksize = stacksize;
    }
}

long size_of(Type ty)
{
    if (ty.type == TypeName.INT)
        return 4;
    assert(ty.type == TypeName.PTR);
    return 8;
}

private:

struct Var
{
    Type type;
    size_t offset;
}

Var[string] vars;
long stacksize;

void walk(Node* node)
{
    with (NodeType) switch (node.op)
    {
    case NUM:
        return;
    case IDENT:
        if (node.name !in vars)
            error("undefined variable: %s", node.name);
        node.op = NodeType.LVAR;
        node.type = vars[node.name].type;
        node.offset = vars[node.name].offset;
        return;
    case VARDEF:
        stacksize += 8;
        node.offset = stacksize;

        Var var;
        var.type = node.type;
        var.offset = stacksize;
        vars[node.name] = var;

        if (node.initialize)
            walk(node.initialize);
        return;
    case IF:
        walk(node.cond);
        walk(node.then);
        if (node.els)
            walk(node.els);
        return;
    case FOR:
        walk(node.initialize);
        walk(node.cond);
        walk(node.inc);
        walk(node.fbody);
        return;
    case ADD:
    case SUB:
        walk(node.lhs);
        walk(node.rhs);

        if (node.rhs.type.type == TypeName.PTR)
            swap(node.lhs, node.rhs);

        if (node.rhs.type.type == TypeName.PTR)
            error("'pointer %s pointer' is not defined", node.op);

        node.type = node.lhs.type;
        return;
    case MUL:
    case DIV:
    case ASSIGN:
    case LESS_THAN:
    case LOGAND:
    case LOGOR:
        walk(node.lhs);
        walk(node.rhs);
        node.type = node.lhs.type;
        return;
    case DEREF:
        walk(node.expr);
        if (node.expr.type.type != TypeName.PTR)
            error("operand must be a pointer");
        node.type = *(node.expr.type.ptr_of);
        return;
    case RETURN:
        walk(node.expr);
        node.type = Type(TypeName.INT);
        return;
    case CALL:
        foreach (ref v; node.args)
            walk(&v);
        return;
    case FUNC:
        foreach (ref v; node.args)
            walk(&v);
        walk(node.fbody);
        return;
    case COMP_STMT:
        foreach (ref v; node.stmts)
            walk(v);
        return;
    case EXPR_STMT:
        walk(node.expr);
        return;
    default:
        assert(0, "unknown node type");
    }
}
