const std = @import("std");
const c = @import("c.zig").c;

db: ?*c.sqlite3 = null,

pub fn init() @This() {
    var self: @This() = .{};

    self.initECS();

    return self;
}

pub fn run(self: @This()) !void {
    _ = self;
}

fn initECS(self: @This()) void {
    if (c.sqlite3_open(":memory:", &self.db) != c.SQLITE_OK) {
        std.log.err("Failed to open database: {s}\n", .{c.sqlite3_errmsg(self.db)});
        std.process.exit(1);
    }
    defer if (c.sqlite3_close(self.db) != c.SQLITE_OK)
        std.log.err("Failed to close database: {s}\n", .{c.sqlite3_errmsg(self.db)});
}
