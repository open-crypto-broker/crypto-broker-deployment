# Changelog

The list of commits in this changelog is automatically generated in the release process.
The commits follow the Conventional Commit specification.

## [0.1.0] - 2025-12-02

### 🚀 Features

- Adjust workflow files and remove local config files (#38)
- Added docker compose test deployment (#26)
- Add git cliff for changelog generation (#23)
- Add delay loop for Cloud Foundry deployment (#20)
- Add release-please workflow (#16)
- New CSR with multiple OU entries (#15)
- Add multiple clients to Cloud Foundry manifest file (#14)
- Adding grep support for macos in taskfile (#12)
- Test custom subject API from clients (#11)
- Add OS and ARCH support for all public task commands (#9)
- A branch can be specified when building clients, server, deploying or testing (#5)
- Run nightly taskfile pipeline (#3)
- Initial-commit

### 🐛 Bug Fixes

- Add branch and tag for git push in workflow (#34)
- Change GitHub workflow token (#21)
- Update CSR files for Cloud Foundry deployment (#18)
- [**breaking**] Adjust certificate output after clients changed to PEM encoding (#6)
- Adjust deployment to Cloud Foundry (#2)

### 💼 Other

- Adjustment of files for the new cli-based structure (#39)

### 🚜 Refactor

- Adjust GitHub ref name in release changelog (#37)
- Adjust flags in dockerfiles (#36)
- Add new profiles, new certificates, and csrs, adjust tests (#35)
- Restructured docker compose files, updated values for Helm (#28)
- Adjust git push command (#33)
- Change environment name (#32)
- Add environment to workflow file (#31)
- Use GitHub App for release workflow (#30)
- Adjust git cliff workflow (#29)
- Remove release-please workflow (#27)
- Adjust taskfile and Cloud Foundry deployment to new CLI flags (#24)

### ⚙️ Miscellaneous Tasks

- Delete CHANGELOG and tag (#41)
