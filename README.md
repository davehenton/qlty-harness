# Qlty Coverage Plugin for Harness CI

Publish code coverage reports to [Qlty Cloud](https://qlty.sh) from a Harness CI
pipeline using a [Plugin step](https://developer.harness.io/docs/continuous-integration/use-ci/use-drone-plugins/run-a-drone-plugin-in-ci/),
without hand-writing an install-and-publish shell script.

The qlty CLI already auto-detects Harness CI, so build ID, commit, and branch are
read from the environment automatically — no `--override-*` flags required.

## Usage

Add a Plugin step after your test step produces a coverage report:

```yaml
- step:
    type: Plugin
    name: Publish Coverage to Qlty
    identifier: publish_coverage
    spec:
      image: ghcr.io/qltysh/qlty-harness:1
      envVariables:
        QLTY_COVERAGE_TOKEN: <+secrets.getValue("QLTY_COVERAGE_TOKEN")>
      settings:
        files: target/lcov.info
        format: lcov
```

Coverage runs on any Harness build infrastructure, including Kubernetes.

## Authentication

Provide the coverage token as the `QLTY_COVERAGE_TOKEN` environment variable
(recommended, via a Harness secret) or the `token` setting.

Workspace tokens (prefix `qltcw_`) work without extra configuration — the project
is inferred from the repository. Set the `project` setting only to override it.

## Settings

| Setting | Description | Default |
| --- | --- | --- |
| `files` | Coverage report file(s) to upload. Comma- or space-separated. | |
| `format` | Report format: `lcov`, `cobertura`, `clover`, `coverprofile`, `jacoco`, `simplecov`, `qlty`. Inferred if omitted. | |
| `token` | Coverage token. Prefer the `QLTY_COVERAGE_TOKEN` env var. | |
| `project` | Project name. Inferred from the repository; set only to override. | |
| `tag` | Tag/name for this upload (e.g. a matrix OS). | |
| `add_prefix` | Prefix to add to file paths in the payload. | |
| `strip_prefix` | Prefix to strip from absolute paths. | |
| `name` | Name to identify this upload. | |
| `total_parts_count` | Total number of parts Qlty should expect. | `1` |
| `incomplete` | Mark the coverage data as incomplete. | `false` |
| `skip_missing_files` | Skip coverage data for files not on disk. | `false` |
| `validate` | Validate the coverage data. | `true` |
| `validate_file_threshold` | Validation threshold percentage (0–100). | |
| `verbose` | Enable extra logging. | `false` |
| `dry_run` | Build the report but do not upload. | `false` |
| `skip_errors` | Do not fail the build if the upload errors. | `true` |
| `working_directory` | Directory to run the CLI in. | `.` |
| `qlty_version` | Pin a specific qlty CLI version. | latest |

## How it works

This is a thin image: the qlty CLI is installed at runtime by the entrypoint
rather than baked in, so uploads always use the current CLI without rebuilding
the image on every qlty release. Pin `qlty_version` when you need a fixed version.

Plugin `settings:` are passed to the container as `PLUGIN_<KEY>` environment
variables, which the entrypoint maps to `qlty coverage publish` flags.
