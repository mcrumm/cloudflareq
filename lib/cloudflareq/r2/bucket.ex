defmodule Cloudflareq.R2.Bucket do
  @moduledoc """
  A struct representing a Cloudflare R2 bucket.

  ## Fields

    * `:name` - the bucket name.
    * `:creation_date` - ISO8601 timestamp of when the bucket was created.
    * `:location` - the bucket location hint, e.g. `"WNAM"`.
    * `:storage_class` - the default storage class, e.g. `"Standard"`.
  """

  defstruct [:name, :creation_date, :location, :storage_class]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          creation_date: String.t() | nil,
          location: String.t() | nil,
          storage_class: String.t() | nil
        }

  @doc """
  Creates a new `Cloudflareq.R2.Bucket` struct from a Cloudflare API response map.
  """
  def new(%{} = map) do
    %__MODULE__{
      name: map["name"],
      creation_date: map["creation_date"],
      location: map["location"],
      storage_class: map["storage_class"]
    }
  end
end
