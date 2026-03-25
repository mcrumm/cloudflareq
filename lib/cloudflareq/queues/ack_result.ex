defmodule Cloudflareq.Queues.AckResult do
  @moduledoc """
  A struct representing the result of a queue message acknowledgment.

  ## Fields

    * `:ack_count` - number of messages successfully acknowledged.
    * `:retry_count` - number of messages queued for retry.
    * `:warnings` - list of warning strings, if any.
  """

  defstruct [:ack_count, :retry_count, :warnings]

  @type t :: %__MODULE__{
          ack_count: integer() | nil,
          retry_count: integer() | nil,
          warnings: [String.t()]
        }

  @doc """
  Creates a new `Cloudflareq.Queues.AckResult` struct from a Cloudflare API response map.
  """
  def new(%{} = map) do
    %__MODULE__{
      ack_count: map["ackCount"],
      retry_count: map["retryCount"],
      warnings: map["warnings"] || []
    }
  end
end
