defmodule Cloudflareq.TokenError do
  @moduledoc """
  An exception raised when a Cloudflare API token is not active.

  ## Fields

    * `:status` - the token status, either `"disabled"` or `"expired"`.
  """

  defexception [:status]

  @type t :: %__MODULE__{
          status: String.t()
        }

  @impl true
  def message(%__MODULE__{status: status}) do
    "token is #{status}"
  end
end
