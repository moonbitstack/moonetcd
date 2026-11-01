# CHANGE-ME

One sentence saying what this is.

```moonbit
@CHANGE-ME.greet("moonbit")
```

Run `moon run src/examples/tour` for the whole surface in one go.

## Starting from this template

1. `gh repo create moonbitstack/<name> --template moonbitstack/moonkit --public`
2. Replace `CHANGE-ME` everywhere: `moon.mod` (name and repository), the
   `moon.pkg` files and sources that import the library, and this file's title.
3. The library is the root package in `src/`, so users write `@<name>.f`. Split it
   into subpackages named after what they do (`base64/`, `sha2/`, `jwt/`) only
   where a user would want one without the rest. Delete `src/cmd/` if the
   repository ships no binary.
4. Fill in `keywords` and `description` in `moon.mod`. The description is what
   mooncakes shows, so it says what the package is and what it is not.
5. Write the specification link into every `moon.pkg`.

## What is here and what is not

| Carried | Why |
|:--|:--|
| `.github/workflows/` | GitHub does not inherit workflows; every repository needs its own copy |
| `moon.mod`, `src/`, `src/cmd/main/`, `src/examples/tour/` | Sources under `src/` so the root holds only entry points; the library is the root package, the binary and the examples sit beside it |
| `.gitignore`, `.moonignore` | The second one exists because `.gitignore`'s `!.git*` would otherwise pull the whole object database into a published tarball |
| `LICENSE` | Apache-2.0, the same across the organisation |

**Issue and pull-request templates are not here.** The organisation's `.github`
repository supplies them to every repository that has none of its own; a copy
here would shadow that one and then drift from it. A repository adds its own
only when it needs something the organisation's does not cover.

## The gate

Every commit passes this, with each exit code seen to be zero:

```bash
moon clean && moon fmt && moon check --target all --deny-warn \
  && moon build --target all && moon test --target all
```

Before a release, `moon info --target all && git diff --exit-code` as well: the
generated interface is checked in, and a difference means the interface moved
without anyone saying so.

## Releasing

Push a signed tag `v<version>`. `release.yml` runs the tests first and publishes
only if they pass and the organisation variable `MOONCAKES_PUBLISH` is `true`.
The major version stays at 0.

## Licence

Apache-2.0.
