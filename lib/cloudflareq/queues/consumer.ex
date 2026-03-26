defmodule Cloudflareq.Queues.Consumer do
  @moduledoc """
  A struct representing a Cloudflare Queue consumer.

  ## Fields

    * `:consumer_id` - the consumer identifier.
    * `:type` - the consumer type, `"worker"` or `"http_pull"`.
    * `:script_name` - the Worker script name (for worker type consumers).
    * `:queue_name` - the queue name.
    * `:dead_letter_queue` - the dead letter queue name, if configured.
    * `:created_on` - ISO8601 timestamp of when the consumer was created.
    * `:settings` - consumer settings map. Keys vary by type:
      for workers: `:batch_size`, `:max_concurrency`, `:max_retries`,
      `:max_wait_time_ms`, `:retry_delay`;
      for http_pull: `:batch_size`, `:max_retries`, `:retry_delay`,
      `:visibility_timeout_ms`.
  """

  defstruct [
    :consumer_id,
    :type,
    :script_name,
    :queue_name,
    :dead_letter_queue,
    :created_on,
    :settings
  ]

  @type t :: %__MODULE__{
          consumer_id: String.t() | nil,
          type: String.t() | nil,
          script_name: String.t() | nil,
          queue_name: String.t() | nil,
          dead_letter_queue: String.t() | nil,
          created_on: String.t() | nil,
          settings: map() | nil
        }

  @doc false
  def new(%{} = map) do
    %__MODULE__{
      consumer_id: map["consumer_id"],
      type: map["type"],
      script_name: map["script_name"],
      queue_name: map["queue_name"],
      dead_letter_queue: map["dead_letter_queue"],
      created_on: map["created_on"],
      settings: normalize_settings(map["settings"])
    }
  end

  defp normalize_settings(nil), do: nil

  defp normalize_settings(map) when is_map(map) do
    %{
      batch_size: map["batch_size"],
      max_concurrency: map["max_concurrency"],
      max_retries: map["max_retries"],
      max_wait_time_ms: map["max_wait_time_ms"],
      retry_delay: map["retry_delay"],
      visibility_timeout_ms: map["visibility_timeout_ms"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
