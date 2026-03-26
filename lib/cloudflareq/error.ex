defmodule Cloudflareq.Error do
  @moduledoc """
  An exception representing a Cloudflare API error response.

  ## Fields

    * `:errors` - a list of `Cloudflareq.ErrorData` structs from the API response.
    * `:headers` - the HTTP response headers from the error response.
  """

  defexception errors: [], headers: %{}

  @type t :: %__MODULE__{
          errors: [Cloudflareq.ErrorData.t(), ...],
          headers: %{optional(String.t()) => [String.t()]}
        }

  @impl true
  def message(%__MODULE__{errors: errors}) do
    Enum.map_join(errors, "; ", &Exception.message/1)
  end
end
