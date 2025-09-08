const std = @import("std");
const print = std.debug.print;
const tokens = @import("tokens.zig");
const lexer = @import("lexer.zig");
const Parser = @import("Parser.zig");
const err = @import("errors.zig");
const Tok = @import("tokens.zip").Tok;
const File = std.fs.File;
const List = std.ArrayListUnmanaged;

pub fn main() !void {
    var args = std.process.args();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alc = gpa.allocator();
    const program_name = args.next() orelse unreachable;
    const filename = args.next() orelse {
        print("Usage: {s} filename\n", .{program_name});
        std.process.exit(1);
    };
    var file = std.fs.cwd().openFile(filename, .{}) catch |e| {
        print("Error opening file: {}\n\n", .{e});
        std.process.exit(1);
    };
    defer file.close();
    GLOBAL.filesize = (try file.stat()).size;

    const source: []u8 = try alc.alloc(u8, GLOBAL.filesize + 1);
    source[GLOBAL.filesize] = 0;
    defer alc.free(source);

    _ = try file.readAll(source);

    var err_table = try err.ErrTable.init(alc);
    defer err_table.deinit();

    var token_list = try List(tokens.Tok).initCapacity(alc, GLOBAL.filesize / 2);
    defer token_list.deinit(alc);

    var sidxs = try List(u32).initCapacity(alc, GLOBAL.filesize / 2);
    defer sidxs.deinit(alc);

    var lens = try List(u16).initCapacity(alc, GLOBAL.filesize / 2);
    defer lens.deinit(alc);

    var cols = try List(u16).initCapacity(alc, GLOBAL.filesize / 2);
    defer cols.deinit(alc);

    // LEXING
    try lexer.lex(source, alc, &err_table, &token_list, &sidxs, &lens, &cols);

    // PARSING
    var parser_inst = try Parser.init(alc, source, &err_table, &token_list, &sidxs, &lens, &cols);
    defer parser_inst.deinit();

    _ = try parser_inst.parse();

    printEverything(&token_list, &sidxs, &lens, &cols, &parser_inst, &err_table);
}

pub const GLOBAL = struct {
    pub var filesize: u64 = 0;
};

fn printEverything(token_list: *List(tokens.Tok), sidxs: *List(u32), lens: *List(u16), cols: *List(u16), parser_inst: *Parser, err_table: *err.ErrTable) void {
    print("========================\n", .{});
    print("         Tokens         \n", .{});
    print("========================\n", .{});
    for (0..token_list.items.len) |n| {
        print("[{d}]  {}, sidx: {d}, len: {d}, col: {d}\n", .{ n, token_list.items[n], sidxs.items[n], lens.items[n], cols.items[n] });
    }

    print("\n\n", .{});

    print("========================\n", .{});
    print("       Main Nodes       \n", .{});
    print("========================\n", .{});
    for (1..parser_inst.nl.items.len) |i| {
        const l, const r = parser_inst.gl.items[i].to_pairs_u32();
        print("[{}]\t{},    \tsubnodes: ({}, {}),\ttidx: {d} \t[{}]\n", .{ i, parser_inst.nl.items[i], l, r, parser_inst.tidxs.items[i], i });
    }
    print("\n", .{});

    print("========================\n", .{});
    print("       Extra Nodes       \n", .{});
    print("========================\n", .{});
    var i: u64 = 0;
    const l = parser_inst.extra.items.len;
    while (i < l) : (i += 4) {
        if (0 == parser_inst.extra.items[i].number)
            print("[{d}] Delim,\t\t", .{i})
        else
            print("[{d}] -> {},\t\t", .{ i, parser_inst.extra.items[i].number });

        if (i + 1 < l)
            if (0 == parser_inst.extra.items[i + 1].number)
                print("[{d}] Delim,\t\t", .{i + 1})
            else
                print("[{d}] -> {},\t\t", .{ i + 1, parser_inst.extra.items[i + 1].number });

        if (i + 2 < l)
            if (0 == parser_inst.extra.items[i + 2].number)
                print("[{d}] Delim,\t\t", .{i + 2})
            else
                print("[{d}] -> {},\t\t", .{ i + 2, parser_inst.extra.items[i + 2].number });

        if (i + 3 < l)
            if (0 == parser_inst.extra.items[i + 3].number)
                print("[{d}] Delim,\t\t", .{i + 3})
            else
                print("[{d}] -> {},\t\t", .{ i + 3, parser_inst.extra.items[i + 3].number });
        print("\n", .{});
    }

    print("\n", .{});
    print("Errors:\n", .{});
    err_table.report();
}
