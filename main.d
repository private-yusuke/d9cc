module main;

import std.stdio : writeln, stderr;
import std.algorithm : each, map;
import std.range : enumerate, join;
import token, regalloc, util;
import parse : parse, Node;
import gen_x86 : gen_x86;
import gen_ir : gen_ir, Function;
import sema : sema;

int main(string[] args)
{
    string input;

    bool dump_ir1 = false;
    bool dump_ir2 = false;

    if (args.length == 3 && args[1] == "-dump-ir1")
    {
        dump_ir1 = true;
        input = args[2];
    }
    else if (args.length == 3 && args[1] == "-dump-ir2")
    {
        dump_ir2 = true;
        input = args[2];
    }
    else if (args.length != 2)
    {
        stderr.writeln("Usage: d9cc [-dump-ir] <code>");
        return 1;
    }
    else
        input = args[1];
    try
    {
        Token[] tokens = tokenize(input);
        Node[] nodes = parse(tokens);
        sema(nodes);
        Function[] fns = gen_ir(nodes);

        if (dump_ir1)
            fns.map!(f => f.ir)
                .join
                .enumerate
                .each!(p => stderr.writefln("%3d: %s", p[0], p[1]));

        alloc_regs(fns);

        if (dump_ir2)
            fns.map!(f => f.ir)
                .join
                .enumerate
                .each!(p => stderr.writefln("%3d: %s", p[0], p[1]));

        gen_x86(fns);
    }
    catch (QuitException e)
    {
        debug
        {
            throw e;
        }
        else
        {
            return e.return_code;
        }
    }
    return 0;
}
