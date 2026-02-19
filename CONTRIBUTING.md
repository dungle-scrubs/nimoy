# Contributing

## Development Setup

```bash
git clone https://github.com/dungle-scrubs/nimoy.git
cd nimoy
```

Install local git hooks:

```bash
brew install trufflehog
cp .githooks/pre-commit .git/hooks/pre-commit
cp .githooks/pre-push .git/hooks/pre-push
chmod +x .git/hooks/pre-commit .git/hooks/pre-push
```

## Build and Test

Build:

```bash
xcodebuild -project Nimoy.xcodeproj -scheme Nimoy -destination 'platform=macOS' build
```

Test:

```bash
xcodebuild test -project Nimoy.xcodeproj -scheme Nimoy -destination 'platform=macOS'
```

## Code Style

- Keep changes focused and minimal.
- Preserve or improve existing comments.
- Add tests for behavior changes.
- Run SwiftLint and SwiftFormat before pushing.

## Commit Messages

This repo uses Conventional Commits for release automation:

- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation
- `refactor:` for code restructuring
- `test:` for test-only changes
- `chore:` for maintenance

Use `feat!:` or `fix!:` only for breaking changes.

## Pull Requests

1. Create a focused branch.
2. Keep PR scope small enough to review in one pass.
3. Include test evidence in the PR description.
4. Link related issues.
5. Fill the PR template completely.

If your change affects public behavior, update `README.md` or changelog notes.
