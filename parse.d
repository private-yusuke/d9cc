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
    IF, // "if"
    RETURN, // Return statement
    CALL, // Function call
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
    Node*[] stmts; // Compound statement

    // "if"
    Node* cond;
    Node* then;
    Node* els;

    Node[] args;
}

Node* parse(Token[] tokens)
{
    return compound_stmt(tokens);
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
        node.type = NodeType.NUM;
        node.name = t.name;
        node.val = t.val;
        return node;
    }

    if (t.type == TokenType.IDENT)
    {
        node.name = t.name;

        if (!consume(tokens, TokenType.LEFT_PAREN))
        {
            node.type = NodeType.IDENT;
            return node;
        }

        node.type = NodeType.CALL;
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
    Token t = tokens[pos];

    switch (t.type)
    {
    case TokenType.IF:
        pos++;
        node.type = NodeType.IF;
        expect(tokens, '(');
        node.cond = assign(tokens);
        expect(tokens, ')');

        node.then = stmt(tokens);

        if (consume(tokens, TokenType.ELSE))
            node.els = stmt(tokens);

        return node;
    case TokenType.RETURN:
        pos++;
        node.type = NodeType.RETURN;
        node.expr = assign(tokens);
        expect(tokens, ';');
        return node;
    default:
        node.type = NodeType.EXPR_STMT;
        node.expr = assign(tokens);
        expect(tokens, ';');
        return node;
    }
}

Node* compound_stmt(Token[] tokens)
{
    Node* node = new Node;
    node.type = NodeType.COMP_STMT;
    node.stmts = [];

    while (true)
    {
        if (tokens[pos].type == TokenType.EOF)
            return node;

        node.stmts ~= stmt(tokens);
    }
    return node;
}
