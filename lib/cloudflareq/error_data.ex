defmodule Cloudflareq.ErrorData do
  @moduledoc """
  A Cloudflare API error detail.

  Each error in a `Cloudflareq.Error` contains one or more of these structs,
  representing individual error entries from the Cloudflare API response.

  ## Fields

    * `:code` - the Cloudflare error code (integer, typically >= 1000).
    * `:message` - the human-readable error message.
    * `:documentation_url` - optional URL to relevant Cloudflare documentation.
    * `:source` - optional map with a `:pointer` key indicating the offending field.
  """

  defexception [:code, :message, :documentation_url, :source]

  @type t :: %__MODULE__{
          code: integer() | nil,
          message: String.t() | nil,
          documentation_url: String.t() | nil,
          source: %{pointer: String.t()} | nil
        }

  @doc """
  Creates a new `ErrorData` from a decoded JSON error map.
  """
  def new(%{} = map) do
    %__MODULE__{
      code: map["code"],
      message: map["message"],
      documentation_url: map["documentation_url"],
      source: parse_source(map["source"])
    }
  end

  @impl true
  def message(%__MODULE__{code: code, message: msg}) do
    "[#{code}] #{msg}"
  end

  defp parse_source(%{"pointer" => pointer}), do: %{pointer: pointer}
  defp parse_source(_), do: nil
end
