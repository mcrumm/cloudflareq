defmodule Cloudflareq.Queues.Queue do
  @moduledoc """
  A struct representing a Cloudflare Queue.

  ## Fields

    * `:queue_id` - the queue identifier.
    * `:queue_name` - the queue name.
    * `:created_on` - when the queue was created.
    * `:modified_on` - when the queue was last modified.
    * `:consumers_total_count` - total number of consumers.
    * `:producers_total_count` - total number of producers.
    * `:settings` - queue settings map with keys `:delivery_delay`,
      `:delivery_paused`, and `:message_retention_period`.
  """

  defstruct [
    :queue_id,
    :queue_name,
    :created_on,
    :modified_on,
    :consumers_total_count,
    :producers_total_count,
    :settings
  ]

  @type t :: %__MODULE__{
          queue_id: String.t() | nil,
          queue_name: String.t() | nil,
          created_on: DateTime.t() | nil,
          modified_on: DateTime.t() | nil,
          consumers_total_count: integer() | nil,
          producers_total_count: integer() | nil,
          settings: map() | nil
        }

  @doc false
  def new(%{} = map) do
    %__MODULE__{
      queue_id: map["queue_id"],
      queue_name: map["queue_name"],
      created_on: Cloudflareq.parse_datetime(map["created_on"]),
      modified_on: Cloudflareq.parse_datetime(map["modified_on"]),
      consumers_total_count: map["consumers_total_count"],
      producers_total_count: map["producers_total_count"],
      settings: normalize_settings(map["settings"])
    }
  end

  defp normalize_settings(nil), do: nil

  defp normalize_settings(map) when is_map(map) do
    %{
      delivery_delay: map["delivery_delay"],
      delivery_paused: map["delivery_paused"],
      message_retention_period: map["message_retention_period"]
    }
  end
end
