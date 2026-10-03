# CodisAI runtime API

The public GDScript facade is `codisai_client.gd` (`class_name CodisAI`). It wraps the `CodisAINative` class registered by the native GDExtension and provides model lifecycle methods, background generation, cancellation, status queries, and typed signals.

See the repository [README](../../../README.md) for build and API usage instructions. Native binaries are generated into `addons/codisai/bin/` and are not committed.
