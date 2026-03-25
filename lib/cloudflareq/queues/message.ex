defmodule Cloudflareq.Queues.Message do
  @moduledoc """
  A struct representing a message pulled from a Cloudflare Queue.

  ## Fields

    * `:id` - the message identifier.
    * `:body` - the message body.
    * `:lease_id` - the lease identifier, used for acknowledgment.
    * `:attempts` - the number of delivery attempts.
    * `:metadata` - optional message metadata.
    * `:timestamp_ms` - creation timestamp in milliseconds.
  """

  defstruct [:id, :body, :lease_id, :attempts, :metadata, :timestamp_ms]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          body: term(),
          lease_id: String.t() | nil,
          attempts: integer() | nil,
          metadata: map() | nil,
          timestamp_ms: integer() | nil
        }

  @doc """
  Creates a new `Cloudflareq.Queues.Message` struct from a Cloudflare API response map.
  """
  def new(%{} = map) do
    %__MODULE__{
      id: map["id"],
      body: map["body"],
      lease_id: map["lease_id"],
      attempts: map["attempts"],
      metadata: map["metadata"],
      timestamp_ms: map["timestamp_ms"]
    }
  end
end
