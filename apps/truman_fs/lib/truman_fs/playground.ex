defmodule TrumanFs.Playground do
  @moduledoc """
  Path validation for the TrumanFS playground.

  Implements the "404 Principle" - paths outside the playground appear
  as "not found" rather than "permission denied" to avoid information leakage.

  All path operations should go through this module to ensure consistent
  security behavior across the codebase.
  """

  @doc """
  Validates that a path resolves within the playground root.

  Returns `{:ok, resolved_path}` if the path is safe,
  or `{:error, :outside_playground}` if it would escape.

  Uses Elixir's `Path.safe_relative/2` which protects against:
  - Directory traversal attacks (`../` sequences)
  - Absolute paths outside playground

  ## Examples

      # Relative paths within playground are allowed
      iex> {:ok, path} = TrumanFs.Playground.validate_path("lib/foo.ex", "/playground")
      iex> path
      "/playground/lib/foo.ex"

      # Directory traversal is blocked
      iex> TrumanFs.Playground.validate_path("../escape", "/playground")
      {:error, :outside_playground}

      # Absolute paths outside playground are blocked
      iex> TrumanFs.Playground.validate_path("/etc/passwd", "/playground")
      {:error, :outside_playground}

      # Similar prefix but different directory is blocked
      iex> TrumanFs.Playground.validate_path("/playground2/file", "/playground")
      {:error, :outside_playground}

      # Absolute paths within playground are allowed
      iex> {:ok, path} = TrumanFs.Playground.validate_path("/playground/file", "/playground")
      iex> path
      "/playground/file"

  ## Symlink Limitation

  `Path.safe_relative/2` performs **lexical (string-based) validation only** -
  it does not query the filesystem. Pre-existing symlinks inside the playground
  pointing outside are NOT detected by this function.

  For untrusted environments, the FUSE layer provides defense-in-depth by
  controlling what paths are visible in the first place.
  """
  @spec validate_path(String.t(), String.t()) :: {:ok, String.t()} | {:error, :outside_playground}
  def validate_path(path, playground_root) do
    playground_expanded = Path.expand(playground_root)

    # Reject absolute paths outside playground (transparency principle)
    # Instead of silently confining /etc -> playground/etc, we reject entirely.
    #
    # SECURITY: Must check directory boundary, not just string prefix!
    # "/tmp/playground2" must NOT pass for playground "/tmp/playground"
    if String.starts_with?(path, "/") and not path_within_playground?(path, playground_expanded) do
      {:error, :outside_playground}
    else
      # For relative paths (or absolute within playground), validate normally
      rel_path = Path.relative_to(path, playground_expanded)

      case Path.safe_relative(rel_path, playground_expanded) do
        {:ok, safe_rel} ->
          {:ok, Path.expand(safe_rel, playground_expanded)}

        :error ->
          {:error, :outside_playground}
      end
    end
  end

  @doc """
  Checks if a path is within a playground root.

  This is a simple boundary check that ensures `/tmp/playground2/file`
  is NOT considered within `/tmp/playground` (different directory).

  ## Examples

      iex> TrumanFs.Playground.path_within_playground?("/tmp/pg/file", "/tmp/pg")
      true

      iex> TrumanFs.Playground.path_within_playground?("/tmp/pg2/file", "/tmp/pg")
      false

      iex> TrumanFs.Playground.path_within_playground?("/tmp/pg", "/tmp/pg")
      true

  """
  @spec path_within_playground?(String.t(), String.t()) :: boolean()
  def path_within_playground?(path, playground) do
    path == playground or String.starts_with?(path, playground <> "/")
  end
end
