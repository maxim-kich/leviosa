# Contributing

Contributions are welcome! Keep changes focused and explain the behavior they improve. Discuss new features, dependencies and substantial refactors with the maintainer before starting.

See [Development](docs/development.md) for build requirements and source layout. Run `./test.sh` and `./build.sh` for code changes. Use isolated data for storage tests and back up your gesture library before manual testing.

Preserve cursor and keyboard recovery, cancellation, application focus and Space behavior. Keep the raw trackpad backend isolated; do not substitute screen-edge or pointer-position heuristics while describing them as trackpad gestures. Distinguish simulated tests, native automation and physical hardware observations. State anything you could not test. Visual changes need native screenshots; gesture changes need physical checks where possible. See [Testing](docs/testing.md).

Use one problem per PR. AI-assisted contributions are welcome, but you are responsible for the code, licensing and verification. Do not submit changes or test results you cannot explain. Be respectful; harassment and sharing other people’s private information are not acceptable.

Do not commit signing keys, Keychain exports, credentials, personal gesture libraries, local logs or private screenshots. Contributions are under [MIT](LICENSE); compatible third-party code must retain its notices. Only the maintainer merges changes and publishes releases. There is no promised review or support response time. See [Governance](GOVERNANCE.md).
