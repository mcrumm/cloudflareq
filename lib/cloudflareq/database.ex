defmodule Cloudflareq.Database do
  @moduledoc """
  A struct representing a Cloudflare D1 database.

  ## Fields

    * `:uuid` - the database identifier.
    * `:name` - the database name.
    * `:version` - the database version, e.g. `"production"`.
    * `:created_at` - ISO8601 timestamp of when the database was created.
    * `:jurisdiction` - the data location jurisdiction, e.g. `"eu"` or `"fedramp"`.
  """

  defstruct [:uuid, :name, :version, :created_at, :jurisdiction]

  @type t :: %__MODULE__{
          uuid: String.t() | nil,
          name: String.t() | nil,
          version: String.t() | nil,
          created_at: String.t() | nil,
          jurisdiction: String.t() | nil
        }

  @doc false
  def new(%{} = map) do
    %__MODULE__{
      uuid: map["uuid"],
      name: map["name"],
      version: map["version"],
      created_at: map["created_at"],
      jurisdiction: map["jurisdiction"]
    }
  end
end
