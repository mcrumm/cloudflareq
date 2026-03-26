defmodule Cloudflareq.R2.Bucket do
  @moduledoc """
  A struct representing a Cloudflare R2 bucket.

  ## Fields

    * `:name` - the bucket name.
    * `:creation_date` - when the bucket was created.
    * `:location` - the bucket location hint, e.g. `"WNAM"`.
    * `:storage_class` - the default storage class, e.g. `"Standard"`.
  """

  defstruct [:name, :creation_date, :location, :storage_class]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          creation_date: DateTime.t() | nil,
          location: String.t() | nil,
          storage_class: String.t() | nil
        }

  @doc false
  def new(%{} = map) do
    %__MODULE__{
      name: map["name"],
      creation_date: Cloudflareq.parse_datetime(map["creation_date"]),
      location: map["location"],
      storage_class: map["storage_class"]
    }
  end
end
