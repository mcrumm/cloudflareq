defmodule Cloudflareq.Token do
  @moduledoc """
  A struct representing a verified Cloudflare API token.

  ## Fields

    * `:id` - the token ID.
    * `:status` - the token status, e.g. `"active"`.
    * `:not_before` - when the token becomes valid.
    * `:expires_on` - when the token expires.
  """

  defstruct [:id, :status, :not_before, :expires_on]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          status: String.t() | nil,
          not_before: DateTime.t() | nil,
          expires_on: DateTime.t() | nil
        }

  @doc false
  def new(%{} = map) do
    %__MODULE__{
      id: map["id"],
      status: map["status"],
      not_before: Cloudflareq.parse_datetime(map["not_before"]),
      expires_on: Cloudflareq.parse_datetime(map["expires_on"])
    }
  end
end
