defmodule TrumanFs do
  @moduledoc """
  TrumanFS - A whitelist-based FUSE filesystem for the AI playground.

  This application provides:

  - `TrumanFs.Whitelist` - Manages which paths are visible
  - `TrumanFs.Playground` - Path validation and security

  The FUSE daemon (`truman_fused`) communicates with this application
  via JSON-over-stdio to check path permissions before exposing files.
  """
end
