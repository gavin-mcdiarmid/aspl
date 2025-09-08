const std = @import("std");
const ArrayList = std.ArrayList;
const Tok = @import("tokens.zig").Tok;
const Allocator = std.mem.Allocator;

pub const ErrVal = union {
    OutOfMemory: void,
    FileNotFound: void,
    UnexpectedChar: struct { found: u8 },
    UnexpectedToken: struct { found: Tok },
    TokenMismatch: struct { op1: Tok, op2: ?Tok, found: Tok },
    InvalidIndent: struct { expected_indent: u16, found: u16 },
    EarlyEof: void,
};

pub const Err = error{ OutOfMemory, FileNotFound, UnexpectedChar, UnexpectedToken, TokenMismatch, InvalidIndent, EarlyEof };

pub const ErrTable = struct {
    alc: Allocator,
    err_type: ArrayList(Err),
    err: ArrayList(ErrVal),
    locs: ArrayList(u32),
    scratch: ArrayList(u8),
    len: u32,

    pub const Idx = u32;

    pub fn init(alc: Allocator) !ErrTable {
        return ErrTable{
            .alc = alc,
            .err_type = .empty,
            .err = .empty,
            .locs = .empty,
            .scratch = .empty,
            .len = 0,
        };
    }
    pub fn deinit(self: *ErrTable) void {
        self.err_type.deinit(self.alc);
        self.err.deinit(self.alc);
        self.scratch.deinit(self.alc);
        self.locs.deinit(self.alc);
    }
    pub fn submit(self: *ErrTable, loc: u32, err_type: Err, err: ErrVal) !u32 {
        if (self.len == 0) {
            self.err_type = try ArrayList(Err).initCapacity(self.alc, 8);
            self.err = try ArrayList(ErrVal).initCapacity(self.alc, 8);
            self.locs = try ArrayList(u32).initCapacity(self.alc, 8);
        }
        const i: u32 = @intCast(self.err.items.len);
        try self.err_type.append(self.alc, err_type);
        try self.err.append(self.alc, err);
        try self.locs.append(self.alc, loc);
        self.len += 1;
        return i;
    }

    pub fn report(self: *ErrTable) void {
        for (self.err_type.items, self.err.items, self.locs.items, 0..) |err_type, err_val, loc, n| {
            std.debug.print("[{}]  ", .{n});
            switch (err_type) {
                Err.OutOfMemory => std.debug.print("Out of memory at loc {}\n", .{loc}),
                Err.FileNotFound => std.debug.print("File not found at loc {}\n", .{loc}),
                Err.UnexpectedChar => std.debug.print("Unexpected character '{c}' at loc {}\n", .{ err_val.UnexpectedChar.found, loc }),
                Err.UnexpectedToken => std.debug.print("Unexpected token '{}' at loc {}\n", .{ err_val.UnexpectedToken.found, loc }),
                Err.TokenMismatch => {
                    if (err_val.TokenMismatch.op2 == null)
                        std.debug.print("Token mismatch, expected '{}' found '{}' at loc {}\n", .{ err_val.TokenMismatch.op1, err_val.TokenMismatch.found, loc })
                    else
                        std.debug.print("Token mismatch, expected '{}' or '{}', found '{}' at loc {}\n", .{ err_val.TokenMismatch.op1, err_val.TokenMismatch.op2.?, err_val.TokenMismatch.found, loc });
                },
                Err.InvalidIndent => std.debug.print("Invalid indentation, expected {} found {} at loc {}\n", .{ err_val.InvalidIndent.expected_indent, err_val.InvalidIndent.found, loc }),
                Err.EarlyEof => std.debug.print("Encountered end of file before finishing parsing\n", .{}),
                else => unreachable,
            }
        }
    }
};
