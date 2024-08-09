const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const t = target.result;
    const lib = b.addStaticLibrary(.{
        .name = "neco",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    lib.addCSourceFile(.{
        .file = b.path("src/neco.c"),
        .flags = &.{},
    });
    if (t.os.tag == .windows) {
        lib.linkLibrary(b.dependency("winpthreads", .{
            .target = target,
            .optimize = optimize,
        }).artifact("winpthreads"));
        lib.linkSystemLibrary("ws2_32");
    }
    lib.defineCMacro("LLCO_NOUNWIND", "");
    lib.addIncludePath(b.path("src"));
    lib.installHeader(b.path("src/neco.h"), "neco.h");
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "neco",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(lib);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
