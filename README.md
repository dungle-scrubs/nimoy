# Nimoy

Nimoy is a macOS calculator notebook for fast, natural-language math.
It supports variables, units, currencies, crypto conversion, and inline
results while you type.

## Features

- Natural-language arithmetic (`18 apples + 23`)
- Variables and aggregates (`sum`, `average`, `count`)
- Unit conversion (length, mass, time, volume, CSS units)
- Currency and crypto conversion with live rates
- Multi-page workspace with quick search and actions palette
- Optional AI generation and autocomplete

## Install

```bash
brew install dungle-scrubs/nimoy/nimoy
```

## Requirements

- macOS 14+
- Xcode 16+ (for building from source)

## Build from Source

```bash
git clone https://github.com/dungle-scrubs/nimoy.git
cd nimoy
xcodebuild -project Nimoy.xcodeproj -scheme Nimoy -destination 'platform=macOS' build
```

To run tests:

```bash
xcodebuild test -project Nimoy.xcodeproj -scheme Nimoy -destination 'platform=macOS'
```

You can also open `Nimoy.xcodeproj` in Xcode and run the `Nimoy` scheme.

## AI Providers

Nimoy supports local and cloud providers:

- Local (MLX)
- Local (Ollama)
- Cloud (Groq)

AI is optional. Core calculator behavior does not depend on AI.

## Security and Privacy

- No credentials are committed in this repository.
- API keys are read from environment variables or local user defaults.

## Known Limitations

- Some evaluator edge cases are intentionally skipped in tests until parser
  behavior is finalized.
- Live currency and crypto rates depend on third-party APIs.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

## Security Policy

Read [SECURITY.md](SECURITY.md) to report vulnerabilities.

## License

MIT. See [LICENSE](LICENSE).
