module github.com/bazelbuild/rules_docker

go 1.15

// IMPORTANT: Keep in versions in sync with repositories/go_repositories.bzl
// until we add a gazelle update-repos rule.
require (
	github.com/ghodss/yaml v1.0.0
	github.com/google/go-containerregistry v0.5.1
	github.com/kylelemons/godebug v1.1.0
	github.com/pkg/errors v0.9.1
	gopkg.in/yaml.v2 v2.3.0
)
