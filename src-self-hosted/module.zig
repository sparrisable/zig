const std = @import("std");
const mem = std.mem;
const Buffer = std.Buffer;
const llvm = @import("llvm.zig");
const c = @import("c.zig");
const builtin = @import("builtin");
const Target = @import("target.zig").Target;

pub const Module = struct {
    allocator: &mem.Allocator,
    name: Buffer,
    root_src_path: Buffer,
    module: llvm.ModuleRef,
    context: llvm.ContextRef,
    builder: llvm.BuilderRef,
    target: Target,
    build_mode: builtin.Mode,
    zig_lib_dir: []const u8,

    verbose_tokenization: bool,
    verbose_ast_tree: bool,
    verbose_ast_render: bool,
    verbose_ir: bool,
    verbose_llvm_ir: bool,

    const Kind = enum {
        Exe,
        Lib,
        Obj,
    };

    pub fn create(allocator: &mem.Allocator, name: []const u8, root_src_path: []const u8, target: &const Target,
        kind: Kind, build_mode: builtin.Mode, zig_lib_dir: []const u8) -> %&Module
    {
        var name_buffer = %return Buffer.init(allocator, name);
        %defer name_buffer.deinit();

        var root_src_path_buf = %return Buffer.init(allocator, root_src_path);
        %defer root_src_path_buf.deinit();

        const context = c.LLVMContextCreate() ?? return error.OutOfMemory;
        %defer c.LLVMContextDispose(context);

        const module = c.LLVMModuleCreateWithNameInContext(name_buffer.ptr(), context) ?? return error.OutOfMemory;
        %defer c.LLVMDisposeModule(module);

        const builder = c.LLVMCreateBuilderInContext(context) ?? return error.OutOfMemory;
        %defer c.LLVMDisposeBuilder(builder);

        const module_ptr = allocator.create(Module);
        %defer allocator.destroy(module_ptr);

        *module_ptr = Module {
            .allocator = allocator,
            .name = name_buffer,
            .root_src_path = root_src_path_buf,
            .module = module,
            .context = context,
            .builder = builder,
            .target = *target,
            .kind = kind,
            .build_mode = build_mode,
            .zig_lib_dir = zig_lib_dir,

            .verbose_tokenization = false,
            .verbose_ast_tree = false,
            .verbose_ast_render = false,
            .verbose_ir = false,
            .verbose_llvm_ir = false,
        };
        return module_ptr;
    }

    fn dump(self: &Module) {
        c.LLVMDumpModule(self.module);
    }

    pub fn destroy(self: &Module) {
        c.LLVMDisposeBuilder(self.builder);
        c.LLVMDisposeModule(self.module);
        c.LLVMContextDispose(self.context);
        self.root_src_path.deinit();
        self.name.deinit();

        self.allocator.destroy(self);
    }

    pub fn build(self: &Module) -> %void {
        const root_src_real_path = os.path.real(self.allocator, self.root_src_path.toSlice()) %% |err| {
            %return self.appendError("unable to open '{}': {}", self.root_src_path.toSlice(), err);
            return err;
        };
        %defer self.allocator.free(root_src_real_path);

        const source_code = io.readFileAlloc(root_src_real_path, self.allocator) %% |err| {
            %return self.appendError("unable to open '{}': {}", root_src_real_path, err);
            return err;
        };
        %defer self.allocator.free(source_code);

        
    }
};
