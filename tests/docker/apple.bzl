def _create_banana_directory_impl(ctx):
    out = ctx.actions.declare_directory("banana")
    ctx.actions.run(
        executable = "bash",
        arguments = ["-c", "mkdir -p %s/pear && touch %s/pear/grape" % (out.path, out.path)],
        outputs = [out],
    )
    return [
        DefaultInfo(
            files = depset([out]),
        ),
    ]

create_banana_directory = rule(
    implementation = _create_banana_directory_impl,
)
