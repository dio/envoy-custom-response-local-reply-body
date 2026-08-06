# Envoy custom response local reply body reproducer

Minimal configuration-only reproducer for
[envoyproxy/envoy#45346](https://github.com/envoyproxy/envoy/issues/45346).

The example shows whether a custom response local policy can use the body that originally produced
an Envoy local reply as the input to `%LOCAL_REPLY_BODY%`.

## Scenarios

The single Envoy configuration exposes four direct-response routes:

| Route | Purpose | Current release | Patched Envoy |
|-------|---------|-----------------|---------------|
| `/control` | No custom response policy | `control body` | `control body` |
| `/existing-body` | Format the route's body without configuring a policy body | `[]` | `[route body]` |
| `/configured-body` | Explicit policy body remains authoritative | `[configured body]` | `[configured body]` |
| `/empty-policy` | Policy with neither `body` nor `body_format` remains empty | empty | empty |

The proposed behavior is limited to local replies. It does not buffer or expose arbitrary streamed
upstream response bodies. When `LocalResponsePolicy.body` is configured, it continues to take
precedence over the body that produced the local reply.

## Envoy patch

The patch is available as
[envoyproxy/envoy#46555](https://github.com/envoyproxy/envoy/pull/46555) and on the
[`dio/custom-response-local-reply-body`](https://github.com/dio/envoy/tree/dio/custom-response-local-reply-body)
branch. The demo build is pinned to Envoy commit
[`4e53852609`](https://github.com/dio/envoy/commit/4e53852609).
It carries the local reply body as a non-owning view during `onLocalReply`, copies it in the custom
response filter, and uses the copy as the formatter input only when the local response policy does
not configure its own body.

The downloadable demo binary is published on the
[`envoy-custom-response-local-reply-body-v1`](https://github.com/dio/envoy-custom-response-local-reply-body/releases/tag/envoy-custom-response-local-reply-body-v1)
release. The current release provides a Darwin ARM64 fastbuild asset and its build metadata. It is
for reproducing this issue, not for production deployment.

## Run the patched build

> [!WARNING]
> `make run` downloads and executes an unreviewed candidate Envoy binary from the internet. Review
> the candidate patch, release provenance, and checksum first, and run it only in an isolated,
> non-production environment. To avoid the download, build Envoy from the candidate source and set
> `ENVOY_BIN` to that binary.

```sh
make run
```

`make run` downloads the patched binary for the current operating system and architecture when a
release asset is available and it is not already present. Use a local Envoy binary instead:

```sh
make run ENVOY_BIN=/path/to/envoy
```

In another shell:

```sh
make observe
make check-patched
```

The patched output is:

```text
control:         control body
existing body:  [route body]
configured body:[configured body]
empty policy:   <>
```

## Observe the current behavior

Run the same configuration with an official Envoy image:

```sh
make run-baseline
```

Then run `make observe` and `make check-baseline` in another shell. The `/existing-body` result is
`[]`, demonstrating that the formatter currently starts with an empty local reply body. The
remaining scenarios are controls and produce the same result before and after the patch. In
particular, `/empty-policy` proves that the patch does not preserve the existing body when no
formatter is configured.
