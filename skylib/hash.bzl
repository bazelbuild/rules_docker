"""Functions for producing the hash of an artifact."""

def sha256(ctx, artifact, execution_requirements = None):
    """Create an action to compute the SHA-256 of an artifact."""
    out = ctx.actions.declare_file(artifact.basename + ".sha256")
    ctx.actions.run(
        executable = ctx.executable.sha256,
        arguments = [artifact.path, out.path],
        inputs = [artifact],
        outputs = [out],
        mnemonic = "SHA256",
        execution_requirements = execution_requirements,
    )
    return out

tools = {
    "sha256": attr.label(
        default = Label("//container/go/cmd/sha256:sha256"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
}
