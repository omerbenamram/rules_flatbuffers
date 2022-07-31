load("//flatbuffers/toolchain_defs:toolchain_defs.bzl", "toolchain_target_for_repo")

RS_LANG_REPO = "rules_flatbuffers_rs_toolchain"
RS_LANG_TOOLCHAIN = toolchain_target_for_repo(RS_LANG_REPO)
RS_LANG_SHORTNAME = "rs"
RS_LANG_DEFAULT_RUNTIME = "@com_github_google_flatbuffers//:flatbuffers"
RS_LANG_FLATC_ARGS = [
    "--rust",
    # This is necessary to preserve the directory hierarchy for generated headers to be relative to
    # the workspace root as bazel expects.
    "--keep-prefix",
]
# CC_LANG_DEFAULT_EXTRA_FLATC_ARGS = [
#     "--gen-mutable",
#     "--gen-name-strings",
#     "--reflect-names",
# ]
