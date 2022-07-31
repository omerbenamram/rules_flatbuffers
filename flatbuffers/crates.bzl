load("@rules_rust//crate_universe:defs.bzl", "crate", "crates_vendor")

crates_vendor(
    name = "crates_vendor",
    mode = "remote",
    packages = {
        "flatbuffers": crate.spec(
            version = "2",
        ),
    },
    repository_name = "crate_index",
    tags = ["manual"],
    vendor_path = "crates",
)
