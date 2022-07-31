load("//flatbuffers/internal:flatbuffers_lang_toolchain.bzl", "FlatbuffersLangToolchainInfo")
load("//flatbuffers/internal:flatbuffers_toolchain.bzl", "FlatbuffersToolchainInfo")
load("//flatbuffers/internal:run_flatc.bzl", "run_flatc")
load("//flatbuffers/internal:string_utils.bzl", "replace_extension")
load("//flatbuffers/toolchain_defs:toolchain_defs.bzl", "FLATBUFFERS_TOOLCHAIN")
load("//flatbuffers/toolchain_defs:rs_defs.bzl", "RS_LANG_TOOLCHAIN")
load("//flatbuffers:flatbuffers_library.bzl", "FlatbuffersInfo")
load("@rules_rust//rust:defs.bzl", "rust_library")

DEFAULT_SUFFIX = "_generated"
RS_FILE_EXTENSION = "rs"

FlatbuffersCrateInfo = provider(fields = {
    "srcs": "header files for this target (non-transitive)",
    "deps": "depset of generated headers",
})

def _flatbuffers_rs_info_aspect_impl(target, ctx):
    srcs = [
        ctx.actions.declare_file(replace_extension(
            string = src.basename,
            old_extension = src.extension,
            new_extension = RS_FILE_EXTENSION,
            suffix = DEFAULT_SUFFIX,
        ))
        for src in target[FlatbuffersInfo].srcs
    ]

    # depend of additional generated crates.
    srcs_transitive = depset(
        direct = srcs,
        transitive = [dep[FlatbuffersCrateInfo].deps for dep in ctx.rule.attr.deps],
    )

    run_flatc(
        ctx = ctx,
        fbs_toolchain = ctx.attr._fbs_toolchain[FlatbuffersToolchainInfo],
        fbs_lang_toolchain = ctx.attr._fbs_lang_toolchain[FlatbuffersLangToolchainInfo],
        srcs = target[FlatbuffersInfo].srcs,
        srcs_transitive = target[FlatbuffersInfo].srcs_transitive,
        includes_transitive = depset([dep.dirname for dep in srcs_transitive.to_list()]),
        outputs = srcs,
    )

    return FlatbuffersCrateInfo(
        srcs = srcs,
        deps = srcs_transitive,
    )

def _rs_flatbuffers_genrule_impl(ctx):
    toolchain = ctx.attr._fbs_lang_toolchain[FlatbuffersLangToolchainInfo]
    headers_transitive = depset(
        transitive = [dep[FlatbuffersCrateInfo].deps for dep in ctx.attr.deps],
    )

    return [
        DefaultInfo(files = headers_transitive),
        toolchain,
    ]

flatbuffers_rs_info_aspect = aspect(
    implementation = _flatbuffers_rs_info_aspect_impl,
    attr_aspects = ["deps"],
    attrs = {
        "_fbs_toolchain": attr.label(
            providers = [FlatbuffersToolchainInfo],
            default = FLATBUFFERS_TOOLCHAIN,
        ),
        "_fbs_lang_toolchain": attr.label(
            providers = [FlatbuffersLangToolchainInfo],
            default = RS_LANG_TOOLCHAIN,
        ),
    },
)

rs_flatbuffers_genrule = rule(
    attrs = {
        "deps": attr.label_list(
            aspects = [flatbuffers_rs_info_aspect],
            providers = [FlatbuffersInfo],
        ),
        "_fbs_toolchain": attr.label(
            providers = [FlatbuffersToolchainInfo],
            default = FLATBUFFERS_TOOLCHAIN,
        ),
        "_fbs_lang_toolchain": attr.label(
            providers = [FlatbuffersLangToolchainInfo],
            default = RS_LANG_TOOLCHAIN,
        ),
    },
    output_to_genfiles = True,
    implementation = _rs_flatbuffers_genrule_impl,
)

def _strip_extension(f):
    return f.basename[:-len(f.extension) - 1]

def _rust_proto_lib_impl(ctx):
    """Generate a lib.rs file for the crates."""
    lib_rs = ctx.actions.declare_file("lib.rs")

    content = []

    deps = ctx.attr.deps
    seen = []

    for dep in deps:
        aspect = dep[FlatbuffersCrateInfo]

        for src in aspect.srcs:
            modname = _strip_extension(src)
            if modname in seen:
                continue

            s = '''
            pub mod %s {
                include!("%s");
            }
            ''' % (_strip_extension(src), src.basename)

            # s = 'include!("%s/%s");' % (label.label.name, src.basename)
            content.append(s)
            seen.append(modname)

        # # TODO: files are generated to ("../modname/<>.rs")
        # for src in aspect.deps.to_list():
        #     modname = _strip_extension(src)

        #     if modname in seen:
        #         continue
        #     s = '''
        #     pub mod %s {
        #         include!("../%s");
        #     }
        #     ''' % (_strip_extension(src), src.short_path)

        #     # s = 'include!("%s/%s");' % (label.label.name, src.basename)
        #     content.append(s)
        #     seen.append(modname)

    ctx.actions.write(
        lib_rs,
        "\n".join(content) + "\n",
        False,
    )

    return [DefaultInfo(
        files = depset([lib_rs]),
    )]

rs_flatbuffers_lib = rule(
    implementation = _rust_proto_lib_impl,
    attrs = {
        "deps": attr.label_list(
            aspects = [flatbuffers_rs_info_aspect],
            providers = [FlatbuffersInfo],
        ),
    },
)

def rs_flatbuffers_library(name, deps, **kwargs):
    generated_srcs = name + "_genrule"
    generated_lib = name + "_lib"

    rs_flatbuffers_genrule(
        name = generated_srcs,
        deps = deps,
    )

    rs_flatbuffers_lib(
        name = generated_lib,
        deps = deps,
    )

    rust_library(
        name = name,
        srcs = [
            generated_srcs,
            generated_lib,
        ],
        deps = ["@crate_index//:flatbuffers"],
        edition = "2021",
        **kwargs
    )
