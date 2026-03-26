defmodule Cloudflareq.Token do
  @moduledoc """
  A struct representing a verified Cloudflare API token.

  ## Fields

    * `:id` - the token ID.
    * `:status` - the token status, e.g. `"active"`.
    * `:not_before` - ISO8601 timestamp of when the token becomes valid.
    * `:expires_on` - ISO8601 timestamp of when the token expires.
  """

  defstruct [:id, :status, :not_before, :expires_on]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          status: String.t() | nil,
          not_before: String.t() | nil,
          expires_on: String.t() | nil
        }

  @doc """
  Creates a new `Cloudflareq.Token` struct from a Cloudflare API response map.
  """
  def new(%{} = map) do
    %__MODULE__{
      id: map["id"],
      status: map["status"],
      not_before: map["not_before"],
      expires_on: map["expires_on"]
    }
  end
end
