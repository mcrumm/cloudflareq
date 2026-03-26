defmodule Cloudflareq.Queues do
  @moduledoc """
  A `Req` plugin for the [Cloudflare Queues](https://developers.cloudflare.com/queues/) HTTP API.

  ## Options

    * `:cf_account_id` - Required. The Cloudflare account ID.
    * `:cf_api_token` - The Cloudflare API token. When set, the token is sent
      as a bearer token in the `Authorization` header.

  ## Examples

      # Create a client
      req = Cloudflareq.Queues.new(cf_account_id: "acct_id", cf_api_token: "token")

      # Queue CRUD
      {:ok, queue} = Cloudflareq.Queues.create_queue(req, "my-queue")
      {:ok, queues} = Cloudflareq.Queues.list_queues(req)

      # Pull-based consumption
      {:ok, %{messages: messages}} = Cloudflareq.Queues.pull_messages(req, queue.queue_id, batch_size: 10)
      {:ok, _} = Cloudflareq.Queues.ack_messages(req, queue.queue_id,
        acks: Enum.map(messages, &%{lease_id: &1.lease_id})
      )
  """

  @options Cloudflareq.shared_options() ++ [:queues_operation]

  @doc """
  Creates a new `Req.Request` with the Queues plugin attached.

  ## Examples

      req = Cloudflareq.Queues.new(cf_account_id: "acct_id", cf_api_token: "token")
  """
  def new(opts \\ []) do
    {plugin_opts, req_opts} = Keyword.split(opts, @options)
    Req.new(req_opts) |> attach(plugin_opts)
  end

  @doc """
  Attaches the Queues plugin to an existing `Req.Request`.

  ## Examples

      req = Req.new() |> Cloudflareq.Queues.attach(cf_account_id: "acct_id", cf_api_token: "token")
  """
  def attach(%Req.Request{} = req, opts \\ []) do
    req
    |> Req.Request.prepend_request_steps(queues_run: &run/1)
    |> Req.Request.register_options(@options)
    |> Req.Request.merge_options(opts)
  end

  # -- Queue CRUD --

  @doc """
  Lists all queues for the account.

  Returns `{:ok, [%Cloudflareq.Queues.Queue{}]}` or `{:error, reason}`.

  ## Examples

      {:ok, queues} = Cloudflareq.Queues.list_queues(req)
  """
  def list_queues(req, opts \\ []) do
    opts = Keyword.merge(opts, queues_operation: :list_queues)

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Returns a `Stream` that lazily paginates through all queues.

  Each element is a `%Cloudflareq.Queues.Queue{}` struct. On error,
  `{:error, reason}` is emitted as the final element.

  ## Options

    * `:per_page` - number of results per page.

  ## Examples

      Cloudflareq.Queues.stream_queues(req) |> Enum.to_list()
  """
  def stream_queues(req, opts \\ []) do
    Cloudflareq.Stream.pages(fn cursor ->
      page = cursor || 1
      fetch_queues_page(req, Keyword.put(opts, :page, page))
    end)
  end

  defp fetch_queues_page(req, opts) do
    {query_opts, opts} = Keyword.split(opts, [:page, :per_page])
    opts = Keyword.merge(opts, queues_operation: {:list_queues_page, query_opts})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: %{queues: queues, next_page: next}}} -> {:ok, {queues, next}}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Creates a new queue with the given `name`.

  Returns `{:ok, %Cloudflareq.Queues.Queue{}}` or `{:error, reason}`.

  ## Examples

      {:ok, queue} = Cloudflareq.Queues.create_queue(req, "my-queue")
  """
  def create_queue(req, name, opts \\ []) do
    opts = Keyword.merge(opts, queues_operation: {:create_queue, name})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Gets details for a queue by its `queue_id`.

  Returns `{:ok, %Cloudflareq.Queues.Queue{}}` or `{:error, reason}`.

  ## Examples

      {:ok, queue} = Cloudflareq.Queues.get_queue(req, "queue-uuid")
  """
  def get_queue(req, queue_id, opts \\ []) do
    opts = Keyword.merge(opts, queues_operation: {:get_queue, queue_id})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Updates a queue's name or settings.

  `params` is a keyword list or map with optional keys:
    * `:queue_name` - the new queue name.
    * `:settings` - a map with `:delivery_delay`, `:delivery_paused`,
      or `:message_retention_period`.

  Returns `{:ok, %Cloudflareq.Queues.Queue{}}` or `{:error, reason}`.

  ## Examples

      {:ok, queue} = Cloudflareq.Queues.update_queue(req, "queue-uuid", queue_name: "renamed")
  """
  def update_queue(req, queue_id, params, opts \\ []) do
    params = if is_list(params), do: Map.new(params), else: params
    opts = Keyword.merge(opts, queues_operation: {:update_queue, queue_id, params})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Deletes a queue by its `queue_id`.

  Returns `:ok` on success, or `{:error, reason}`.

  ## Examples

      :ok = Cloudflareq.Queues.delete_queue(req, "queue-uuid")
  """
  def delete_queue(req, queue_id, opts \\ []) do
    opts = Keyword.merge(opts, queues_operation: {:delete_queue, queue_id})

    case Req.request(req, opts) do
      {:ok, _response} -> :ok
      {:error, exception} -> {:error, exception}
    end
  end

  # -- Consumer management --

  @doc """
  Lists consumers for a queue.

  Returns `{:ok, [%Cloudflareq.Queues.Consumer{}]}` or `{:error, reason}`.

  ## Examples

      {:ok, consumers} = Cloudflareq.Queues.list_consumers(req, "queue-uuid")
  """
  def list_consumers(req, queue_id, opts \\ []) do
    opts = Keyword.merge(opts, queues_operation: {:list_consumers, queue_id})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Returns a `Stream` that lazily paginates through consumers for a queue.

  Each element is a `%Cloudflareq.Queues.Consumer{}` struct. On error,
  `{:error, reason}` is emitted as the final element.

  ## Options

    * `:per_page` - number of results per page.

  ## Examples

      Cloudflareq.Queues.stream_consumers(req, "queue-uuid") |> Enum.to_list()
  """
  def stream_consumers(req, queue_id, opts \\ []) do
    Cloudflareq.Stream.pages(fn cursor ->
      page = cursor || 1
      fetch_consumers_page(req, queue_id, Keyword.put(opts, :page, page))
    end)
  end

  defp fetch_consumers_page(req, queue_id, opts) do
    {query_opts, opts} = Keyword.split(opts, [:page, :per_page])
    opts = Keyword.merge(opts, queues_operation: {:list_consumers_page, queue_id, query_opts})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: %{consumers: consumers, next_page: next}}} ->
        {:ok, {consumers, next}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  @doc """
  Creates a consumer on a queue.

  `params` is a keyword list or map with:
    * `:type` - Required. `"worker"` or `"http_pull"`.
    * `:script_name` - Required for worker type.
    * `:dead_letter_queue` - Optional dead letter queue name.
    * `:settings` - Optional consumer settings map.

  Returns `{:ok, %Cloudflareq.Queues.Consumer{}}` or `{:error, reason}`.

  ## Examples

      {:ok, consumer} = Cloudflareq.Queues.create_consumer(req, "queue-uuid",
        type: "http_pull", settings: %{batch_size: 10})
  """
  def create_consumer(req, queue_id, params, opts \\ []) do
    params = if is_list(params), do: Map.new(params), else: params
    opts = Keyword.merge(opts, queues_operation: {:create_consumer, queue_id, params})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Updates a consumer on a queue.

  Returns `{:ok, %Cloudflareq.Queues.Consumer{}}` or `{:error, reason}`.

  ## Examples

      {:ok, consumer} = Cloudflareq.Queues.update_consumer(req, "queue-uuid", "consumer-uuid",
        type: "http_pull", settings: %{batch_size: 20})
  """
  def update_consumer(req, queue_id, consumer_id, params, opts \\ []) do
    params = if is_list(params), do: Map.new(params), else: params

    opts =
      Keyword.merge(opts,
        queues_operation: {:update_consumer, queue_id, consumer_id, params}
      )

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Deletes a consumer from a queue.

  Returns `:ok` on success, or `{:error, reason}`.

  ## Examples

      :ok = Cloudflareq.Queues.delete_consumer(req, "queue-uuid", "consumer-uuid")
  """
  def delete_consumer(req, queue_id, consumer_id, opts \\ []) do
    opts = Keyword.merge(opts, queues_operation: {:delete_consumer, queue_id, consumer_id})

    case Req.request(req, opts) do
      {:ok, _response} -> :ok
      {:error, exception} -> {:error, exception}
    end
  end

  # -- Message operations --

  @doc """
  Sends a single message to a queue.

  Returns `:ok` on success, or `{:error, reason}`.

  ## Options

    * `:content_type` - `"json"` (default) or `"text"`.
    * `:delay_seconds` - optional delay before the message becomes visible.

  ## Examples

      :ok = Cloudflareq.Queues.send_message(req, "queue-uuid", %{event: "signup"})
      :ok = Cloudflareq.Queues.send_message(req, "queue-uuid", "hello", content_type: "text")
  """
  def send_message(req, queue_id, body, opts \\ []) do
    {msg_opts, opts} = Keyword.split(opts, [:content_type, :delay_seconds])
    opts = Keyword.merge(opts, queues_operation: {:send_message, queue_id, body, msg_opts})

    case Req.request(req, opts) do
      {:ok, _response} -> :ok
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Sends a batch of messages to a queue.

  `messages` is a list where each element is a keyword list or map with:
    * `:body` - Required. The message body.
    * `:content_type` - Optional. `"json"` (default) or `"text"`.
    * `:delay_seconds` - Optional delay.

  Returns `:ok` on success, or `{:error, reason}`.

  ## Examples

      :ok = Cloudflareq.Queues.send_message_batch(req, "queue-uuid", [
        [body: %{event: "a"}],
        [body: "hello", content_type: "text"]
      ])
  """
  def send_message_batch(req, queue_id, messages, opts \\ []) when is_list(messages) do
    opts = Keyword.merge(opts, queues_operation: {:send_message_batch, queue_id, messages})

    case Req.request(req, opts) do
      {:ok, _response} -> :ok
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Pulls messages from a queue.

  Returns `{:ok, %{messages: [%Cloudflareq.Queues.Message{}], message_backlog_count: integer()}}` or `{:error, reason}`.

  ## Options

    * `:batch_size` - number of messages to pull (default determined by server).
    * `:visibility_timeout_ms` - how long the messages are invisible to other
      consumers after being pulled.

  ## Examples

      {:ok, %{messages: messages}} = Cloudflareq.Queues.pull_messages(req, "queue-uuid", batch_size: 10)
  """
  def pull_messages(req, queue_id, opts \\ []) do
    {pull_opts, opts} = Keyword.split(opts, [:batch_size, :visibility_timeout_ms])
    opts = Keyword.merge(opts, queues_operation: {:pull_messages, queue_id, pull_opts})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Acknowledges and/or retries messages.

  `params` is a keyword list or map with:
    * `:acks` - list of maps with `:lease_id` to acknowledge.
    * `:retries` - list of maps with `:lease_id` and optional `:delay_seconds` to retry.

  Returns `{:ok, %Cloudflareq.Queues.AckResult{}}` or `{:error, reason}`.

  ## Examples

      {:ok, result} = Cloudflareq.Queues.ack_messages(req, "queue-uuid",
        acks: [%{lease_id: "lease-1"}],
        retries: [%{lease_id: "lease-2", delay_seconds: 10}]
      )
  """
  def ack_messages(req, queue_id, params, opts \\ []) do
    params = if is_list(params), do: Map.new(params), else: params
    opts = Keyword.merge(opts, queues_operation: {:ack_messages, queue_id, params})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  # -- Request step --

  defp run(%Req.Request{} = req) do
    case req.options[:queues_operation] do
      nil ->
        req

      operation ->
        req
        |> Cloudflareq.put_auth()
        |> configure_request(operation)
        |> Req.Request.append_response_steps(queues_handle_response: &handle_response/1)
    end
  end

  defp configure_request(req, :list_queues) do
    Req.merge(req, method: :get, url: queues_url(req, ""))
  end

  defp configure_request(req, {:list_queues_page, query_opts}) do
    params =
      query_opts
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    opts = [method: :get, url: queues_url(req, "")]
    opts = if map_size(params) > 0, do: Keyword.put(opts, :params, params), else: opts
    Req.merge(req, opts)
  end

  defp configure_request(req, {:create_queue, name}) do
    Req.merge(req, method: :post, url: queues_url(req, ""), json: %{"queue_name" => name})
  end

  defp configure_request(req, {:get_queue, queue_id}) do
    Req.merge(req, method: :get, url: queues_url(req, "/#{queue_id}"))
  end

  defp configure_request(req, {:update_queue, queue_id, params}) do
    Req.merge(req,
      method: :put,
      url: queues_url(req, "/#{queue_id}"),
      json: encode_queue_params(params)
    )
  end

  defp configure_request(req, {:delete_queue, queue_id}) do
    Req.merge(req, method: :delete, url: queues_url(req, "/#{queue_id}"))
  end

  defp configure_request(req, {:list_consumers, queue_id}) do
    Req.merge(req, method: :get, url: queues_url(req, "/#{queue_id}/consumers"))
  end

  defp configure_request(req, {:list_consumers_page, queue_id, query_opts}) do
    params =
      query_opts
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    opts = [method: :get, url: queues_url(req, "/#{queue_id}/consumers")]
    opts = if map_size(params) > 0, do: Keyword.put(opts, :params, params), else: opts
    Req.merge(req, opts)
  end

  defp configure_request(req, {:create_consumer, queue_id, params}) do
    Req.merge(req,
      method: :post,
      url: queues_url(req, "/#{queue_id}/consumers"),
      json: encode_consumer_params(params)
    )
  end

  defp configure_request(req, {:update_consumer, queue_id, consumer_id, params}) do
    Req.merge(req,
      method: :put,
      url: queues_url(req, "/#{queue_id}/consumers/#{consumer_id}"),
      json: encode_consumer_params(params)
    )
  end

  defp configure_request(req, {:delete_consumer, queue_id, consumer_id}) do
    Req.merge(req, method: :delete, url: queues_url(req, "/#{queue_id}/consumers/#{consumer_id}"))
  end

  defp configure_request(req, {:send_message, queue_id, body, msg_opts}) do
    content_type = Keyword.get(msg_opts, :content_type, "json")
    json = %{"body" => body, "content_type" => content_type}
    json = maybe_put(json, "delay_seconds", Keyword.get(msg_opts, :delay_seconds))
    Req.merge(req, method: :post, url: queues_url(req, "/#{queue_id}/messages"), json: json)
  end

  defp configure_request(req, {:send_message_batch, queue_id, messages}) do
    encoded = Enum.map(messages, &encode_message/1)

    Req.merge(req,
      method: :post,
      url: queues_url(req, "/#{queue_id}/messages/batch"),
      json: %{"messages" => encoded}
    )
  end

  defp configure_request(req, {:pull_messages, queue_id, pull_opts}) do
    json = %{}
    json = maybe_put(json, "batch_size", Keyword.get(pull_opts, :batch_size))

    json =
      maybe_put(json, "visibility_timeout_ms", Keyword.get(pull_opts, :visibility_timeout_ms))

    Req.merge(req,
      method: :post,
      url: queues_url(req, "/#{queue_id}/messages/pull"),
      json: json
    )
  end

  defp configure_request(req, {:ack_messages, queue_id, params}) do
    json = %{}
    json = maybe_put(json, "acks", params[:acks])
    json = maybe_put(json, "retries", params[:retries])

    Req.merge(req,
      method: :post,
      url: queues_url(req, "/#{queue_id}/messages/ack"),
      json: json
    )
  end

  defp queues_url(req, path) do
    account_id = req.options[:cf_account_id] || raise "missing required option :cf_account_id"
    "#{Cloudflareq.base_url(account_id)}/queues#{path}"
  end

  # -- Encoding helpers --

  defp encode_queue_params(params) do
    json = %{}
    json = maybe_put(json, "queue_name", params[:queue_name])

    case params[:settings] do
      nil ->
        json

      settings ->
        settings = if is_list(settings), do: Map.new(settings), else: settings

        encoded = %{}
        encoded = maybe_put(encoded, "delivery_delay", settings[:delivery_delay])
        encoded = maybe_put(encoded, "delivery_paused", settings[:delivery_paused])

        encoded =
          maybe_put(encoded, "message_retention_period", settings[:message_retention_period])

        Map.put(json, "settings", encoded)
    end
  end

  defp encode_consumer_params(params) do
    json = %{}
    json = maybe_put(json, "type", params[:type])
    json = maybe_put(json, "script_name", params[:script_name])
    json = maybe_put(json, "dead_letter_queue", params[:dead_letter_queue])
    json = maybe_put(json, "settings", params[:settings])
    json
  end

  defp encode_message(msg) do
    msg = if is_list(msg), do: Map.new(msg), else: msg
    json = %{"body" => msg[:body], "content_type" => msg[:content_type] || "json"}
    maybe_put(json, "delay_seconds", msg[:delay_seconds])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # -- Response step --

  defp handle_response({request, response}) do
    Cloudflareq.transform_response(request, response, &transform_result/3)
  end

  defp transform_result(request, result, result_info) when is_list(result) do
    case request.options[:queues_operation] do
      :list_queues ->
        Enum.map(result, &Cloudflareq.Queues.Queue.new/1)

      {:list_queues_page, _} ->
        queues = Enum.map(result, &Cloudflareq.Queues.Queue.new/1)
        %{queues: queues, next_page: next_page(result_info)}

      {:list_consumers, _} ->
        Enum.map(result, &Cloudflareq.Queues.Consumer.new/1)

      {:list_consumers_page, _, _} ->
        consumers = Enum.map(result, &Cloudflareq.Queues.Consumer.new/1)
        %{consumers: consumers, next_page: next_page(result_info)}

      _ ->
        result
    end
  end

  defp transform_result(request, result, _result_info) when is_map(result) do
    case request.options[:queues_operation] do
      {:create_queue, _} -> Cloudflareq.Queues.Queue.new(result)
      {:get_queue, _} -> Cloudflareq.Queues.Queue.new(result)
      {:update_queue, _, _} -> Cloudflareq.Queues.Queue.new(result)
      {:create_consumer, _, _} -> Cloudflareq.Queues.Consumer.new(result)
      {:update_consumer, _, _, _} -> Cloudflareq.Queues.Consumer.new(result)
      {:pull_messages, _, _} -> transform_pull_result(result)
      {:ack_messages, _, _} -> Cloudflareq.Queues.AckResult.new(result)
      _ -> result
    end
  end

  defp transform_result(_request, result, _result_info), do: result

  defp next_page(%{"page" => page, "total_count" => total, "per_page" => per_page})
       when page * per_page < total,
       do: page + 1

  defp next_page(_), do: nil

  defp transform_pull_result(result) do
    %{
      messages: Enum.map(result["messages"] || [], &Cloudflareq.Queues.Message.new/1),
      message_backlog_count: result["message_backlog_count"]
    }
  end
end
