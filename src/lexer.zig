const std = @import("std");
const main = @import("main");
const Tok = @import("tokens.zig").Tok;
const err = @import("errors.zig");
const ErrVal = err.ErrVal;
const Err = err.Err;
const ErrTable = err.ErrTable;
const ArrayList = std.ArrayList;

pub fn lex(source: []const u8, alc: std.mem.Allocator, err_table: *err.ErrTable, token_list: *ArrayList(Tok), locs: *ArrayList(u32), lens: *ArrayList(u16), cols: *ArrayList(u16)) !void {
    var sidx: u32 = 0;
    var col: u16 = 1;
    while (source[sidx] != 0) {
        while (source[sidx] == ' ' or source[sidx] == '\t' or source[sidx] == 0) {
            sidx += 1;
            col += 1;
        }

        const loc = sidx;
        const start_col = col;
        switch (source[sidx]) {
            '\n' => {
                try token_list.append(alc, Tok.Eol);
                sidx += 1;
                col = 1;
                while (source[sidx] != 0) {
                    if (source[sidx] == ' ' or source[sidx] == '\t') {
                        sidx += 1;
                        col += 1;
                    } else if (source[sidx] == '\n') {
                        sidx += 1;
                        col = 1;
                    } else {
                        break;
                    }
                }
            },
            'a'...'z', 'A'...'Z' => {
                while (source[sidx] != 0) {
                    switch (source[sidx]) {
                        'a'...'z', 'A'...'Z', '-', '_', '0'...'9' => {
                            sidx += 1;
                            col += 1;
                        },
                        else => {
                            break;
                        },
                    }
                }
                if (is_keyword(source[loc..sidx])) |k| {
                    try token_list.append(alc, k);
                } else {
                    try token_list.append(alc, Tok.Name);
                }
            },
            '0'...'9' => {
                var dot_found = false;
                while (source[sidx] != 0) {
                    switch (source[sidx]) {
                        '0'...'9' => {
                            sidx += 1;
                            col += 1;
                        },
                        '.' => {
                            sidx += 1;
                            col += 1;
                            dot_found = true;
                        },
                        else => {
                            break;
                        },
                    }
                }
                if (dot_found) {
                    try token_list.append(alc, Tok.FloatLit);
                } else {
                    try token_list.append(alc, Tok.IntLit);
                }
            },
            '\"' => {
                sidx += 1;
                col += 1;
                while (source[sidx] != '\"') {
                    sidx += 1;
                    col += 1;
                    if (sidx == source.len) {
                        _ = try err_table.submit(@intCast(token_list.items.len), Err.EarlyEof, ErrVal{ .EarlyEof = {} });
                        return;
                    }
                }
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.StrLit);
            },
            '\'' => {
                sidx += 1;
                while (source[sidx] != '\'') {
                    sidx += 1;
                    col += 1;
                }
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.ChrLit);
            },
            '.' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.Dot);
            },
            ',' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.Comma);
            },
            '=' => {
                sidx += 1;
                col += 1;
                if (source[sidx] == '=') {
                    sidx += 1;
                    col += 1;
                    try token_list.append(alc, Tok.EqEq);
                } else {
                    try token_list.append(alc, Tok.Eq);
                }
            },
            '!' => {
                sidx += 1;
                col += 1;
                if (source[sidx] == '=') {
                    sidx += 1;
                    col += 1;
                    try token_list.append(alc, Tok.Neq);
                } else {
                    try token_list.append(alc, Tok.Bang);
                }
            },
            '+' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.Plus);
            },
            '-' => {
                sidx += 1;
                col += 1;
                if (source[sidx] == '>') {
                    sidx += 1;
                    col += 1;
                    try token_list.append(alc, Tok.Arrow);
                } else {
                    try token_list.append(alc, Tok.Sub);
                }
            },
            '*' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.Mult);
            },
            '/' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.Div);
            },
            ':' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.Colon);
            },
            ';' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.Semicolon);
            },
            '{' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.BraceL);
            },
            '}' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.BraceR);
            },
            '(' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.ParenL);
            },
            ')' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.ParenR);
            },
            '[' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.BrackL);
            },
            ']' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.BrackR);
            },
            '<' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.Lt);
            },
            '>' => {
                sidx += 1;
                col += 1;
                try token_list.append(alc, Tok.Gt);
            },
            else => {
                std.debug.print("char : {c}\n", .{source[sidx]});
                try token_list.append(alc, Tok.LexErr);
                _ = try err_table.submit(@intCast(cols.items.len), Err.UnexpectedChar, ErrVal{ .UnexpectedChar = .{ .found = source[sidx] } });
                // .UnexpectedChar{ .loc = loc, .found = source[idx] }
                while (source[sidx] != 0 and source[sidx] != '\n') {
                    sidx += 1;
                }
                sidx += 1;
                col = 0;
            },
        }

        try cols.append(alc, start_col);
        try locs.append(alc, loc);
        try lens.append(alc, @intCast(sidx - loc));
    }
}

fn is_keyword(string: []const u8) ?Tok {
    if (string[0] < 'a' or 'z' < string[0]) return null;
    return std.meta.stringToEnum(Tok, string);
}
