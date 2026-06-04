{ lib, ... }:

{
  # Required because the test framework's read-only nixpkgs module
  # conflicts with custom nixpkgs.config.
  node.pkgsReadOnly = false;

  # 5 minute timeout (default is 1 hour).
  globalTimeout = 5 * 60;

  # Work around a nixpkgs test driver bug with mypy type checking.
  skipTypeCheck = true;

  # Keep linting enabled (set to true locally for faster iteration).
  skipLint = false;
}
