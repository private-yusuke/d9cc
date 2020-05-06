module parse;

import std.stdio : stderr;
import token, util;

public:

enum NodeType
{
    NUM, // Number literal
    IDENT, // Identifier
    VARDEF, // Variable definition
    LVAR, // Variable reference
    IF, // "if"
    FOR, // "for"
    DEREF, // pointer dereference ("*")
    LOGAND, // &&
    LOGOR, // ||
    RETURN, // Return statement
    CALL, // Function call
    FUNC, // Function definition
    COMP_STMT, // Compound statement
    EXPR_STMT, // Expressions statement
    ASSIGN = '=',
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/',
    LESS_THAN = '<',
}

enum TypeName
{
    INT,
    PTR
}

struct Type
{
    TypeName type;
    Type* ptr_of;
}

struct Node
{
    NodeType op; // Node type
    Type type;

    Node* lhs = null;
    Node* rhs = null;
    int val; // Number literal
    string name; // Identifier
    Node* expr; // "return" or expression stmt
    Node*[] stmts; // Compound statement

    // "if"
    Node* cond;
    Node* then;
    Node* els;

    /*
     * Since D handles "body" as a reserved word,
     * here "fbody" is used as an alternative.
     * "init" -> "initialize"
     */
    Node* initialize;
    Node* inc;
    Node* fbody;

    // Function definition
    long stacksize;

    // Local variable
    long offset;

    Node[] args;
}

Node[] parse(Token[] tokens)
{
    Node[] v;
    while (tokens[pos].type != TokenType.EOF)
        v ~= *func(tokens);
    return v;
}

private:

size_t pos;

void expect(Token[] tokens, char c)
{
    if (tokens[pos].type != cast(TokenType) c)
        error("%s (%s) expected, but got %s (%s)", c, cast(TokenType) c,
                tokens[pos].input, tokens[pos].type);
    pos++;
}

bool consume(Token[] tokens, TokenType type)
{
    if (tokens[pos].type != type)
        return false;
    pos++;
    return true;
}

bool is_typename(Token t)
{
    return t.type == TokenType.INT;
}

Node* new_node(NodeType op, Node* lhs, Node* rhs)
{
    Node* node = new Node;
    node.op = op;
    node.lhs = lhs;
    node.rhs = rhs;
    return node;
}

Node* term(Token[] tokens)
{
    Token t = tokens[pos++];

    if (t.type == '(')
    {
        Node* node = assign(tokens);
        expect(tokens, ')');
        return node;
    }

    Node* node = new Node;

    if (t.type == TokenType.NUM)
    {
        node.op = NodeType.NUM;
        node.name = t.name;
        node.val = t.val;
        return node;
    }

    if (t.type == TokenType.IDENT)
    {
        node.name = t.name;

        if (!consume(tokens, TokenType.LEFT_PAREN))
        {
            node.op = NodeType.IDENT;
            return node;
        }

        node.op = NodeType.CALL;
        node.args = [];
        if (consume(tokens, TokenType.RIGHT_PAREN))
            return node;

        node.args ~= *assign(tokens);
        while (consume(tokens, TokenType.COMMA))
            node.args ~= *assign(tokens);
        expect(tokens, TokenType.RIGHT_PAREN);
        return node;
    }
    error("number expected, but got %s", t.input);
    assert(0);
}

Node* unary(Token[] tokens)
{
    if (consume(tokens, TokenType.ASTERISK))
    {
        Node* node = new Node;
        node.op = NodeType.DEREF;
        node.expr = mul(tokens);
        return node;
    }
    return term(tokens);
}

Node* mul(Token[] tokens)
{
    Node* lhs = unary(tokens);
    while (true)
    {
        Token t = tokens[pos];
        if (t.type != TokenType.ASTERISK && t.type != TokenType.DIV)
            return lhs;
        pos++;
        lhs = new_node(cast(NodeType) t.type, lhs, unary(tokens));
    }
}

Node* add(Token[] tokens)
{
    Node* lhs = mul(tokens);
    while (true)
    {
        Token t = tokens[pos];
        if (t.type != '+' && t.type != '-')
            return lhs;
        pos++;
        lhs = new_node(cast(NodeType) t.type, lhs, mul(tokens));
    }
}

Node* rel(Token[] tokens)
{
    Node* lhs = add(tokens);
    while (true)
    {
        Token t = tokens[pos];
        if (t.type == TokenType.LESS_THAN)
        {
            pos++;
            lhs = new_node(NodeType.LESS_THAN, lhs, add(tokens));
            continue;
        }
        if (t.type == TokenType.GREATER_THAN)
        {
            pos++;
            lhs = new_node(NodeType.LESS_THAN, add(tokens), lhs);
            continue;
        }
        return lhs;
    }
}

Node* logand(Token[] tokens)
{
    Node* lhs = rel(tokens);
    while (true)
    {
        Token t = tokens[pos];
        if (t.type != TokenType.LOGAND)
            return lhs;
        pos++;
        lhs = new_node(NodeType.LOGAND, lhs, rel(tokens));
    }
}

Node* logor(Token[] tokens)
{
    Node* lhs = logand(tokens);
    while (true)
    {
        Token t = tokens[pos];
        if (t.type != TokenType.LOGOR)
            return lhs;
        pos++;
        lhs = new_node(NodeType.LOGOR, lhs, logand(tokens));
    }
}

Node* expr(Token[] tokens)
{
    Node* lhs = mul(tokens);

    while (true)
    {
        TokenType op = tokens[pos].type;
        if (op != '+' && op != '-')
            return lhs;
        pos++;
        lhs = new_node(cast(NodeType) op, lhs, mul(tokens));
    }
}

Type* ptr_of(Type* base)
{
    Type* ty = new Type;
    ty.type = TypeName.PTR;
    ty.ptr_of = base;
    return ty;
}

Node* assign(Token[] tokens)
{
    Node* lhs = logor(tokens);
    if (consume(tokens, TokenType.ASSIGN))
        return new_node(NodeType.ASSIGN, lhs, logor(tokens));
    return lhs;
}

Type type(Token[] tokens)
{
    if (tokens[pos].type != TokenType.INT)
        error("typename expected, but got %s", tokens[pos].input);
    pos++;

    Type* ty = new Type;
    ty.type = TypeName.INT;
    while (consume(tokens, TokenType.ASTERISK))
    {
        Type* t = new Type;
        t.type = TypeName.PTR;
        t.ptr_of = ty;
        ty = t;
    }
    return *ty;
}

Node* decl(Token[] tokens)
{
    Node* node = new Node;
    node.type = type(tokens);
    node.op = NodeType.VARDEF;

    Token t = tokens[pos];
    if (t.type != TokenType.IDENT)
        error("variable name expected, but got %s", t.input);

    node.name = t.name;
    pos++;

    if (consume(tokens, TokenType.ASSIGN))
        node.initialize = assign(tokens);

    expect(tokens, TokenType.SEMICOLONE);
    return node;
}

Node* param(Token[] tokens)
{
    Node* node = new Node;
    node.op = NodeType.VARDEF;
    node.type = type(tokens);

    Token t = tokens[pos];
    if (t.type != TokenType.IDENT)
        error("parameter name expected, but got %s", t.input);
    node.name = t.name;
    pos++;
    return node;
}

Node* expr_stmt(Token[] tokens)
{
    Node* node = new Node;
    node.op = NodeType.EXPR_STMT;
    node.expr = assign(tokens);
    expect(tokens, TokenType.SEMICOLONE);
    return node;
}

Node* stmt(Token[] tokens)
{
    Node* node = new Node;
    Token t = tokens[pos];

    switch (t.type)
    {
    case TokenType.INT:
        return decl(tokens);
    case TokenType.IF:
        pos++;
        node.op = NodeType.IF;
        expect(tokens, '(');
        node.cond = assign(tokens);
        expect(tokens, ')');

        node.then = stmt(tokens);

        if (consume(tokens, TokenType.ELSE))
            node.els = stmt(tokens);

        return node;
    case TokenType.FOR:
        pos++;
        node.op = NodeType.FOR;
        expect(tokens, TokenType.LEFT_PAREN);
        if (is_typename(tokens[pos]))
            node.initialize = decl(tokens);
        else
            node.initialize = expr_stmt(tokens);

        node.cond = assign(tokens);
        expect(tokens, TokenType.SEMICOLONE);
        node.inc = assign(tokens);
        expect(tokens, TokenType.RIGHT_PAREN);
        node.fbody = stmt(tokens);
        return node;
    case TokenType.RETURN:
        pos++;
        node.op = NodeType.RETURN;
        node.expr = assign(tokens);
        expect(tokens, ';');
        return node;
    case TokenType.LEFT_BRACE:
        pos++;
        node.op = NodeType.COMP_STMT;
        node.stmts = [];
        while (!consume(tokens, TokenType.RIGHT_BRACE))
            node.stmts ~= stmt(tokens);
        return node;
    default:
        return expr_stmt(tokens);
    }
}

// multiple statements
Node* compound_stmt(Token[] tokens)
{
    Node* node = new Node;
    node.op = NodeType.COMP_STMT;
    node.stmts = [];

    while (!consume(tokens, TokenType.RIGHT_BRACE))
    {
        node.stmts ~= stmt(tokens);
    }
    return node;
}

/* Since D handles "function" as a reserved word,
 * here "func" is used as an alternative.
 */
Node* func(Token[] tokens)
{
    Node* node = new Node;
    node.op = NodeType.FUNC;
    node.args = [];

    Token t = tokens[pos];
    if (t.type != TokenType.INT)
        error("function return type expected, but got %s", t.input);
    pos++;

    t = tokens[pos];
    if (t.type != TokenType.IDENT)
        error("function name expected, but got %s", t.input);
    node.name = t.name;
    pos++;

    expect(tokens, TokenType.LEFT_PAREN);
    if (!consume(tokens, TokenType.RIGHT_PAREN))
    {
        node.args ~= *param(tokens);
        while (consume(tokens, TokenType.COMMA))
            node.args ~= *param(tokens);
        expect(tokens, TokenType.RIGHT_PAREN);
    }

    expect(tokens, TokenType.LEFT_BRACE);
    node.fbody = compound_stmt(tokens);
    return node;
}
