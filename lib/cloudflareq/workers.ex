defmodule Cloudflareq.Workers do
  @moduledoc """
  A `Req` plugin for the [Cloudflare Workers](https://developers.cloudflare.com/workers/) HTTP API.

  ## Options

    * `:cf_account_id` - Required. The Cloudflare account ID.
    * `:cf_api_token` - The Cloudflare API token. When set, the token is sent
      as a bearer token in the `Authorization` header.

  ## Examples

      # Create a client
      req = Cloudflareq.Workers.new(cf_account_id: "acct_id", cf_api_token: "token")

      # List scripts
      {:ok, scripts} = Cloudflareq.Workers.list_scripts(req)

      # Upload a script
      {:ok, script} = Cloudflareq.Workers.upload_script(req, "my-worker", "export default {}")

      # Download script content
      {:ok, content} = Cloudflareq.Workers.get_script_content(req, "my-worker")
  """

  @options Cloudflareq.shared_options() ++ [:workers_operation]

  @doc """
  Creates a new `Req.Request` with the Workers plugin attached.

  Accepts all Workers options as well as any standard `Req` options.

  ## Examples

      req = Cloudflareq.Workers.new(cf_account_id: "acct_id", cf_api_token: "token")
  """
  def new(opts \\ []) do
    {plugin_opts, req_opts} = Keyword.split(opts, @options)
    Req.new(req_opts) |> attach(plugin_opts)
  end

  @doc """
  Attaches the Workers plugin to an existing `Req.Request`.

  ## Examples

      req = Req.new() |> Cloudflareq.Workers.attach(cf_account_id: "acct_id", cf_api_token: "token")
  """
  def attach(%Req.Request{} = req, opts \\ []) do
    req
    |> Req.Request.prepend_request_steps(workers_run: &run/1)
    |> Req.Request.register_options(@options)
    |> Req.Request.merge_options(opts)
  end

  @doc """
  Lists all Workers scripts for the account.

  Returns `{:ok, scripts}` where `scripts` is a list of `Cloudflareq.Workers.Script`
  structs, or `{:error, reason}`.

  ## Examples

      {:ok, scripts} = Cloudflareq.Workers.list_scripts(req)
  """
  def list_scripts(req, opts \\ []) do
    opts = Keyword.merge(opts, workers_operation: :list_scripts)

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: {:error, _} = error}} -> error
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Returns a `Stream` that lazily paginates through all Workers scripts.

  Each element is a `%Cloudflareq.Workers.Script{}` struct. On error,
  `{:error, reason}` is emitted as the final element.

  ## Options

    * `:per_page` - number of results per page.

  ## Examples

      Cloudflareq.Workers.stream_scripts(req) |> Enum.to_list()
  """
  def stream_scripts(req, opts \\ []) do
    Cloudflareq.Stream.pages(fn cursor ->
      page = cursor || 1
      fetch_scripts_page(req, Keyword.put(opts, :page, page))
    end)
  end

  defp fetch_scripts_page(req, opts) do
    {query_opts, opts} = Keyword.split(opts, [:page, :per_page])
    opts = Keyword.merge(opts, workers_operation: {:list_scripts_page, query_opts})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: {:error, _} = error}} -> error
      {:ok, %Req.Response{body: %{scripts: scripts, next_page: next}}} -> {:ok, {scripts, next}}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Gets the content of a Workers script.

  Returns `{:ok, content}` where `content` is the raw script binary,
  or `{:error, reason}`.

  ## Examples

      {:ok, js} = Cloudflareq.Workers.get_script_content(req, "my-worker")
  """
  def get_script_content(req, script_name, opts \\ []) do
    opts = Keyword.merge(opts, workers_operation: {:get_script_content, script_name})

    case Req.request(req, opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{body: {:error, _} = error}} ->
        error

      {:error, exception} ->
        {:error, exception}
    end
  end

  @doc """
  Uploads a Workers script with metadata.

  `script_content` can be:
    * A binary string for a single-module worker.
    * A list of `{name, content}` tuples for a multi-module worker.

  `metadata` is an optional map of metadata fields (e.g., `"main_module"`,
  `"bindings"`, `"compatibility_date"`).

  Returns `{:ok, %Cloudflareq.Workers.Script{}}` or `{:error, reason}`.

  ## Examples

      {:ok, script} = Cloudflareq.Workers.upload_script(req, "my-worker",
        "export default { fetch() { return new Response('hello') } }")
  """
  def upload_script(req, script_name, script_content, metadata \\ %{}, opts \\ []) do
    opts =
      Keyword.merge(opts,
        workers_operation: {:upload_script, script_name, script_content, metadata}
      )

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: {:error, _} = error}} -> error
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Uploads script content without changing metadata or bindings.

  Returns `{:ok, %Cloudflareq.Workers.Script{}}` or `{:error, reason}`.

  ## Examples

      {:ok, script} = Cloudflareq.Workers.put_script_content(req, "my-worker", "export default {}")
  """
  def put_script_content(req, script_name, script_content, opts \\ []) do
    opts =
      Keyword.merge(opts,
        workers_operation: {:put_script_content, script_name, script_content}
      )

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: {:error, _} = error}} -> error
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Deletes a Workers script.

  Returns `:ok` on success, or `{:error, reason}`.

  ## Options

    * `:force` - when `true`, force-deletes the script even if it has
      bindings to other resources.

  ## Examples

      :ok = Cloudflareq.Workers.delete_script(req, "my-worker")
      :ok = Cloudflareq.Workers.delete_script(req, "my-worker", force: true)
  """
  def delete_script(req, script_name, opts \\ []) do
    {delete_opts, opts} = Keyword.split(opts, [:force])
    force = Keyword.get(delete_opts, :force, false)
    opts = Keyword.merge(opts, workers_operation: {:delete_script, script_name, force})

    case Req.request(req, opts) do
      {:ok, %Req.Response{status: 200}} -> :ok
      {:ok, %Req.Response{body: {:error, _} = error}} -> error
      {:error, exception} -> {:error, exception}
    end
  end

  # -- Request step --

  defp run(%Req.Request{} = req) do
    case req.options[:workers_operation] do
      nil ->
        req

      operation ->
        req
        |> Cloudflareq.put_auth()
        |> configure_request(operation)
        |> Req.Request.append_response_steps(workers_handle_response: &handle_response/1)
    end
  end

  defp configure_request(req, :list_scripts) do
    Req.merge(req, method: :get, url: workers_url(req, ""))
  end

  defp configure_request(req, {:list_scripts_page, query_opts}) do
    params =
      query_opts
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    opts = [method: :get, url: workers_url(req, "")]
    opts = if map_size(params) > 0, do: Keyword.put(opts, :params, params), else: opts
    Req.merge(req, opts)
  end

  defp configure_request(req, {:get_script_content, script_name}) do
    Req.merge(req,
      method: :get,
      url: workers_url(req, "/#{script_name}/content/v2"),
      decode_body: false
    )
  end

  defp configure_request(req, {:upload_script, script_name, content, metadata}) do
    {parts, metadata} = build_upload_parts(content, metadata)

    Req.merge(req,
      method: :put,
      url: workers_url(req, "/#{script_name}"),
      form_multipart:
        [{"metadata", {Jason.encode!(metadata), content_type: "application/json"}} | parts]
    )
  end

  defp configure_request(req, {:put_script_content, script_name, content}) do
    parts =
      case content do
        content when is_binary(content) ->
          [
            {"worker.js",
             {content, content_type: "application/javascript+module", filename: "worker.js"}}
          ]

        modules when is_list(modules) ->
          Enum.map(modules, fn {name, mod_content} ->
            {name,
             {mod_content, content_type: infer_content_type(name), filename: name}}
          end)
      end

    Req.merge(req,
      method: :put,
      url: workers_url(req, "/#{script_name}/content"),
      form_multipart: parts
    )
  end

  defp configure_request(req, {:delete_script, script_name, force}) do
    opts = [method: :delete, url: workers_url(req, "/#{script_name}")]
    opts = if force, do: Keyword.put(opts, :params, %{"force" => "true"}), else: opts
    Req.merge(req, opts)
  end

  defp build_upload_parts(content, metadata) when is_binary(content) do
    part_name = metadata["main_module"] || "worker.js"
    content_type = infer_content_type(part_name)
    metadata = Map.put_new(metadata, "main_module", part_name)
    parts = [{part_name, {content, content_type: content_type, filename: part_name}}]
    {parts, metadata}
  end

  defp build_upload_parts(modules, metadata) when is_list(modules) do
    parts =
      Enum.map(modules, fn {name, mod_content} ->
        {name, {mod_content, content_type: infer_content_type(name), filename: name}}
      end)

    {parts, metadata}
  end

  defp infer_content_type(name) do
    cond do
      String.ends_with?(name, ".mjs") -> "application/javascript+module"
      String.ends_with?(name, ".js") -> "application/javascript+module"
      String.ends_with?(name, ".wasm") -> "application/wasm"
      true -> "application/octet-stream"
    end
  end

  defp workers_url(req, path) do
    account_id = req.options[:cf_account_id] || raise "missing required option :cf_account_id"
    "#{Cloudflareq.base_url(account_id)}/workers/scripts#{path}"
  end

  # -- Response step --

  defp handle_response({request, %Req.Response{status: status, body: body} = response})
       when status in 200..299 do
    case request.options[:workers_operation] do
      {:get_script_content, _} ->
        {request, response}

      _ when is_map(body) ->
        result_info = body["result_info"]

        case Cloudflareq.unwrap_response(body) do
          {:ok, result} ->
            transformed = transform_result(request, result, result_info)
            {request, %{response | body: transformed}}

          {:error, errors} ->
            {request, %{response | body: {:error, errors}}}
        end

      _ ->
        {request, response}
    end
  end

  defp handle_response({request, %Req.Response{body: body} = response}) when is_map(body) do
    case Cloudflareq.unwrap_response(body) do
      {:error, errors} -> {request, %{response | body: {:error, errors}}}
      _ -> {request, response}
    end
  end

  defp handle_response({request, response}) do
    {request, response}
  end

  defp transform_result(request, result, result_info) when is_list(result) do
    case request.options[:workers_operation] do
      :list_scripts ->
        Enum.map(result, &Cloudflareq.Workers.Script.new/1)

      {:list_scripts_page, _} ->
        scripts = Enum.map(result, &Cloudflareq.Workers.Script.new/1)
        %{scripts: scripts, next_page: next_page(result_info)}

      _ ->
        result
    end
  end

  defp transform_result(request, result, _result_info) when is_map(result) do
    case request.options[:workers_operation] do
      {:upload_script, _, _, _} -> Cloudflareq.Workers.Script.new(result)
      {:put_script_content, _, _} -> Cloudflareq.Workers.Script.new(result)
      _ -> result
    end
  end

  defp transform_result(_request, result, _result_info), do: result

  defp next_page(%{"page" => page, "total_count" => total, "per_page" => per_page})
       when page * per_page < total,
       do: page + 1

  defp next_page(_), do: nil
end
