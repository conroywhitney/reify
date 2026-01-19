defmodule TrumanFs.Whitelist do
  @moduledoc """
  Manages which filesystem paths are visible within the playground.

  Uses ETS for storage. Paths are matched by prefix - if a directory
  is whitelisted, all its children are automatically allowed.

  Note: `allowed?/2` currently scans all entries (O(n) where n = number of
  whitelisted paths). For typical usage with small whitelists, this is fine.
  If needed, can be optimized later with a trie-based structure.
  """

  alias TrumanFs.Playground

  defstruct [:table]

  @type t :: %__MODULE__{table: :ets.table()}

  @doc """
  Creates a new whitelist with the given initial paths.

  ## Examples

      iex> whitelist = TrumanFs.Whitelist.new(["/home/user/projects"])
      iex> TrumanFs.Whitelist.allowed?(whitelist, "/home/user/projects/app.ex")
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
  Adds multiple paths to the whitelist at once.

  ## Examples

      iex> whitelist = TrumanFs.Whitelist.new([])
      iex> whitelist = TrumanFs.Whitelist.add_all(whitelist, ["/a", "/b"])
      iex> TrumanFs.Whitelist.allowed?(whitelist, "/a")
      true

  """
  @spec add_all(t(), [String.t()]) :: t()
  def add_all(%__MODULE__{} = whitelist, paths) when is_list(paths) do
    Enum.reduce(paths, whitelist, &add(&2, &1))
  end

  @doc """
  Adds a path to the whitelist.

  This operation is idempotent - adding an already-whitelisted path has no effect.

  ## Examples

      iex> whitelist = TrumanFs.Whitelist.new([])
      iex> whitelist = TrumanFs.Whitelist.add(whitelist, "/home/user/projects")
      iex> TrumanFs.Whitelist.allowed?(whitelist, "/home/user/projects")
      true

  """
  @spec add(t(), String.t()) :: t()
  def add(%__MODULE__{table: table} = whitelist, path) do
    normalized = normalize_path(path)
    :ets.insert(table, {normalized, true})
    whitelist
  end

  @doc """
  Removes multiple paths from the whitelist at once.

  ## Examples

      iex> whitelist = TrumanFs.Whitelist.new(["/a", "/b", "/c"])
      iex> whitelist = TrumanFs.Whitelist.remove_all(whitelist, ["/a", "/b"])
      iex> TrumanFs.Whitelist.allowed?(whitelist, "/c")
      true

  """
  @spec remove_all(t(), [String.t()]) :: t()
  def remove_all(%__MODULE__{} = whitelist, paths) when is_list(paths) do
    Enum.reduce(paths, whitelist, &remove(&2, &1))
  end

  @doc """
  Removes a path from the whitelist.

  This operation is idempotent - removing a non-whitelisted path has no effect.

  ## Examples

      iex> whitelist = TrumanFs.Whitelist.new(["/home/user/projects"])
      iex> whitelist = TrumanFs.Whitelist.remove(whitelist, "/home/user/projects")
      iex> TrumanFs.Whitelist.allowed?(whitelist, "/home/user/projects")
      false

  """
  @spec remove(t(), String.t()) :: t()
  def remove(%__MODULE__{table: table} = whitelist, path) do
    normalized = normalize_path(path)
    :ets.delete(table, normalized)
    whitelist
  end

  @doc """
  Lists all whitelisted paths.

  Returns only the top-level whitelisted paths, not expanded children.

  ## Examples

      iex> whitelist = TrumanFs.Whitelist.new(["/tmp", "/home"])
      iex> TrumanFs.Whitelist.list(whitelist) |> Enum.sort()
      ["/home", "/tmp"]

  """
  @spec list(t()) :: [String.t()]
  def list(%__MODULE__{table: table}) do
    :ets.foldl(fn {path, _}, acc -> [path | acc] end, [], table)
  end

  @doc """
  Checks if a path is allowed by the whitelist.

  A path is allowed if it exactly matches a whitelisted path, or if it's
  a child of a whitelisted directory.

  ## Examples

      iex> whitelist = TrumanFs.Whitelist.new(["/home/user/projects"])
      iex> TrumanFs.Whitelist.allowed?(whitelist, "/home/user/projects")
      true
      iex> TrumanFs.Whitelist.allowed?(whitelist, "/home/user/projects/app/lib/main.ex")
      true
      iex> TrumanFs.Whitelist.allowed?(whitelist, "/etc/passwd")
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
  # Delegates to Playground for consistent boundary checking
  defp child_path?(path, parent) do
    Playground.path_within_playground?(path, parent)
  end

  # Normalizes a path by expanding (resolves .., ., ~) and removing trailing slashes.
  # This is critical for security - prevents path traversal attacks.
  defp normalize_path(path) do
    path
    |> Path.expand()
    |> String.trim_trailing("/")
  end
end
