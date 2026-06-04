# Golden Screenshots

This directory contains golden PNG screenshots for the bargman-greeter-login integration test.

## How to generate goldens

1. Run the test once with `compareGoldens = false` to capture screenshots:
   ```bash
   nix build .#checks.x86_64-linux.bargman-greeter-login-test -L --override-input compareGoldens false
   ```
2. Copy the `login.png` screenshot from the test output to this directory
3. Re-run the test with goldens enabled to verify

## Files
- `login.png` — LightDM webkit2 greeter with bargman-cinematic theme
