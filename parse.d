module parse;

import std.stdio : stderr;
import token, util;

public:

enum NodeType
{
    NUM, // Number literal
    IDENT, // Identifier
    ASSIGN = '=',
    ADD = '+',
    SUB = '-',
    RETURN, // Return statement
    COMP_STMT, // Compound statement
    EXPR_STMT // Expressions statement
}

struct Node
{
    NodeType type; // Node type
    Node* lhs = null;
    Node* rhs = null;
    int val; // Number literal
    string name; // Identifier
    Node* expr; // "return" or expression stmt
    Node[] stmts; // Compound statement
}

Node* parse(Token[] tokens)
{
    return stmt(tokens);
}

private:

size_t pos;

void expect(char c, Token[] tokens)
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

Node* new_node(NodeType op, Node* lhs, Node* rhs)
{
    Node* node = new Node;
    node.type = op;
    node.lhs = lhs;
    node.rhs = rhs;
    return node;
}

Node* term(Token[] tokens)
{
    Node* node = new Node;
    Token t = tokens[pos++];
    if (t.type == TokenType.NUM)
    {
        node.type = NodeType.NUM;
        node.name = t.name;
        node.val = t.val;
        return node;
    }

    if (t.type == TokenType.IDENT)
    {
        node.type = NodeType.IDENT;
        node.name = t.name;
        return node;
    }
    error("number expected, but got %s", t.input);
    assert(0);
}

Node* mul(Token[] tokens)
{
    Node* lhs = term(tokens);
    while (true)
    {
        TokenType op = tokens[pos].type;
        if (op != '*' && op != '/')
            return lhs;
        pos++;
        lhs = new_node(cast(NodeType) op, lhs, term(tokens));
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

Node* assign(Token[] tokens)
{
    Node* lhs = expr(tokens);
    if (consume(tokens, TokenType.ASSIGN))
        return new_node(NodeType.ASSIGN, lhs, expr(tokens));
    return lhs;
}

Node* stmt(Token[] tokens)
{
    Node* node = new Node;
    node.type = NodeType.COMP_STMT;
    node.stmts = [];

    while (true)
    {
        if (tokens[pos].type == TokenType.EOF)
            return node;

        Node e;

        if (tokens[pos].type == TokenType.RETURN)
        {
            pos++;
            e.type = NodeType.RETURN;
            e.expr = assign(tokens);
        }
        else
        {
            e.type = NodeType.EXPR_STMT;
            e.expr = assign(tokens);
        }
        node.stmts ~= e;
        expect(';', tokens);
    }
    return node;
}
