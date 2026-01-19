defmodule ReifyFs.Whitelist do
  @moduledoc """
  Manages which filesystem paths are visible within the playground.

  Uses ETS for O(1) lookups. Paths are matched by prefix - if a directory
  is whitelisted, all its children are automatically allowed.
  """

  defstruct [:table]

  @type t :: %__MODULE__{table: :ets.table()}

  @doc """
  Creates a new whitelist with the given initial paths.

  ## Examples

      iex> whitelist = ReifyFs.Whitelist.new(["/home/user/projects"])
      iex> ReifyFs.Whitelist.allowed?(whitelist, "/home/user/projects/app.ex")
      true

  """
  @spec new([String.t()]) :: t()
  def new(paths) when is_list(paths) do
    table = :ets.new(:whitelist, [:set, :private])

    for path <- paths do
      normalized = normalize_path(path)
      :ets.insert(table, {normalized, true})
    end

    %__MODULE__{table: table}
  end

  @doc """
  Checks if a path is allowed by the whitelist.

  A path is allowed if it exactly matches a whitelisted path, or if it's
  a child of a whitelisted directory.

  ## Examples

      iex> whitelist = ReifyFs.Whitelist.new(["/home/user/projects"])
      iex> ReifyFs.Whitelist.allowed?(whitelist, "/home/user/projects")
      true
      iex> ReifyFs.Whitelist.allowed?(whitelist, "/home/user/projects/app/lib/main.ex")
      true
      iex> ReifyFs.Whitelist.allowed?(whitelist, "/etc/passwd")
      false

  """
  @spec allowed?(t(), String.t()) :: boolean()
  def allowed?(%__MODULE__{table: table}, path) do
    normalized = normalize_path(path)

    :ets.foldl(
      fn {whitelisted_path, _}, acc ->
        acc || child_path?(normalized, whitelisted_path)
      end,
      false,
      table
    )
  end

  # Checks if `path` is equal to or a child of `parent`
  defp child_path?(path, parent) do
    path == parent || String.starts_with?(path, parent <> "/")
  end

  # Normalizes a path by removing trailing slashes
  defp normalize_path(path) do
    path |> String.trim_trailing("/")
  end
end
