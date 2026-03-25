defmodule Cloudflareq.D1 do
  @moduledoc """
  A `Req` plugin for the [Cloudflare D1](https://developers.cloudflare.com/d1/) HTTP API.

  ## Options

    * `:cf_account_id` - Required. The Cloudflare account ID.
    * `:cf_api_token` - The Cloudflare API token. When set, the token is sent
      as a bearer token in the `Authorization` header.
    * `:database_id` - The D1 database UUID. Required for `query/4`, `batch/3`,
      and other database-scoped operations.
    * `:d1_result_format` - The result format for query operations. Defaults to
      `:object`. Set to `:raw` to use the raw query endpoint.

  ## Examples

      # Create a client for a specific database
      req = Cloudflareq.D1.new(cf_account_id: "acct_id", cf_api_token: "token", database_id: "db_id")

      # Run a query
      {:ok, result} = Cloudflareq.D1.query(req, "SELECT * FROM users WHERE id = ?", [1])

      # Attach to an existing Req request
      req = Req.new() |> Cloudflareq.D1.attach(cf_account_id: "acct_id", cf_api_token: "token")
  """

  @options Cloudflareq.shared_options() ++ [:database_id, :d1_result_format, :d1_operation]

  @doc """
  Creates a new `Req.Request` with the D1 plugin attached.

  Accepts all D1 options as well as any standard `Req` options.

  ## Examples

      req = Cloudflareq.D1.new(cf_account_id: "acct_id", cf_api_token: "token", database_id: "db_id")

      req = Cloudflareq.D1.new(cf_account_id: "acct_id", cf_api_token: "token", base_url: :default)
  """
  def new(opts \\ []) do
    {plugin_opts, req_opts} = Keyword.split(opts, @options)
    Req.new(req_opts) |> attach(plugin_opts)
  end

  @doc """
  Attaches the D1 plugin to an existing `Req.Request`.

  ## Examples

      req = Req.new() |> Cloudflareq.D1.attach(cf_account_id: "acct_id", cf_api_token: "token")
  """
  def attach(%Req.Request{} = req, opts \\ []) do
    req
    |> Req.Request.prepend_request_steps(d1_run: &run/1)
    |> Req.Request.register_options(@options)
    |> Req.Request.merge_options(opts)
  end

  @doc """
  Executes a SQL query against a D1 database, raising on error.

  Same as `query/4` but returns the `Cloudflareq.D1.Result` directly or raises.

  ## Examples

      Cloudflareq.D1.query!(req, "SELECT * FROM users WHERE id = ?", [1])
      #=> %Cloudflareq.D1.Result{
      #=>   success: true,
      #=>   rows: [%{"id" => 1, "name" => "Alice"}],
      #=>   meta: %{duration: 0.1, rows_read: 1, rows_written: 0, ...}
      #=> }
  """
  def query!(req, sql, params \\ [], opts \\ []) do
    case query(req, sql, params, opts) do
      {:ok, result} ->
        result

      {:error, errors} when is_list(errors) ->
        raise "D1 query failed: #{Enum.map_join(errors, "; ", &to_string/1)}"

      {:error, exception} ->
        raise exception
    end
  end

  @doc """
  Executes a batch of SQL queries against a D1 database.

  `queries` is a list where each element is either a SQL string or a
  `{sql, params}` tuple.

  Returns `{:ok, results}` where `results` is a list of `Cloudflareq.D1.Result`
  structs, or `{:error, reason}`.

  ## Examples

      Cloudflareq.D1.batch(req, [
        "SELECT * FROM users",
        {"SELECT * FROM posts WHERE user_id = ?", [1]}
      ])
      #=> {:ok, [
      #=>   %Cloudflareq.D1.Result{success: true, rows: [%{"id" => 1, "name" => "Alice"}], meta: %{...}},
      #=>   %Cloudflareq.D1.Result{success: true, rows: [%{"id" => 1, "title" => "Hello"}], meta: %{...}}
      #=> ]}
  """
  def batch(req, queries, opts \\ []) when is_list(queries) do
    opts = Keyword.merge(opts, d1_operation: {:batch, queries})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: results}} when is_list(results) ->
        {:ok, results}

      {:ok, %Req.Response{body: {:error, _} = error}} ->
        error

      {:error, exception} ->
        {:error, exception}
    end
  end

  @doc """
  Lists all D1 databases for the account.

  Returns `{:ok, databases}` where `databases` is a list of database objects,
  or `{:error, reason}`.

  ## Examples

      Cloudflareq.D1.list_databases(req)
      #=> {:ok, [
      #=>   %Cloudflareq.Database{uuid: "xxxx-...", name: "my-database", version: "production", ...},
      #=>   %Cloudflareq.Database{uuid: "yyyy-...", name: "other-db", version: "production", ...}
      #=> ]}
  """
  def list_databases(req, opts \\ []) do
    opts = Keyword.merge(opts, d1_operation: :list_databases)

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Returns a `Stream` that lazily paginates through all D1 databases.

  Each element is a `%Cloudflareq.Database{}` struct. On error,
  `{:error, reason}` is emitted as the final element.

  ## Options

    * `:per_page` - number of results per page.

  ## Examples

      Cloudflareq.D1.stream_databases(req) |> Enum.to_list()
  """
  def stream_databases(req, opts \\ []) do
    Cloudflareq.Stream.pages(fn cursor ->
      page = cursor || 1
      fetch_databases_page(req, Keyword.put(opts, :page, page))
    end)
  end

  defp fetch_databases_page(req, opts) do
    {query_opts, opts} = Keyword.split(opts, [:page, :per_page])
    opts = Keyword.merge(opts, d1_operation: {:list_databases_page, query_opts})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: {:error, _} = error}} -> error
      {:ok, %Req.Response{body: %{databases: dbs, next_page: next}}} -> {:ok, {dbs, next}}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Creates a new D1 database with the given `name`.

  Returns `{:ok, database}` with the created database object,
  or `{:error, reason}`.

  ## Examples

      Cloudflareq.D1.create_database(req, "my-database")
      #=> {:ok, %Cloudflareq.Database{uuid: "xxxx-...", name: "my-database", version: "production", ...}}
  """
  def create_database(req, name, opts \\ []) do
    opts = Keyword.merge(opts, d1_operation: {:create_database, name})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Gets details for a D1 database by its `database_id`.

  Returns `{:ok, database}` with the database object,
  or `{:error, reason}`.

  ## Examples

      Cloudflareq.D1.get_database(req, "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
      #=> {:ok, %Cloudflareq.Database{uuid: "xxxxxxxx-...", name: "my-database", version: "production", ...}}
  """
  def get_database(req, database_id, opts \\ []) do
    opts = Keyword.merge(opts, d1_operation: {:get_database, database_id})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Deletes a D1 database by its `database_id`.

  Returns `:ok` on success, or `{:error, reason}`.

  ## Examples

      :ok = Cloudflareq.D1.delete_database(req, "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
  """
  def delete_database(req, database_id, opts \\ []) do
    opts = Keyword.merge(opts, d1_operation: {:delete_database, database_id})

    case Req.request(req, opts) do
      {:ok, %Req.Response{status: 200}} -> :ok
      {:ok, %Req.Response{body: {:error, _} = error}} -> error
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Executes a SQL query against a D1 database.

  `sql` is the SQL statement and `params` is a list of bind parameters.

  Returns `{:ok, result}` with a `Cloudflareq.D1.Result` struct,
  or `{:error, reason}`.

  ## Examples

      Cloudflareq.D1.query(req, "SELECT * FROM users WHERE id = ?", [1])
      #=> {:ok, %Cloudflareq.D1.Result{
      #=>   success: true,
      #=>   rows: [%{"id" => 1, "name" => "Alice"}],
      #=>   meta: %{
      #=>     duration: 0.1,
      #=>     rows_read: 1,
      #=>     rows_written: 0,
      #=>     changes: 0,
      #=>     last_row_id: 0,
      #=>     size_after: 8192
      #=>   }
      #=> }}

      Cloudflareq.D1.query(req, "INSERT INTO users (name) VALUES (?)", ["Bob"])
      #=> {:ok, %Cloudflareq.D1.Result{
      #=>   success: true,
      #=>   rows: [],
      #=>   meta: %{changes: 1, last_row_id: 2, rows_written: 1, ...}
      #=> }}
  """
  def query(req, sql, params \\ [], opts \\ []) do
    opts = Keyword.merge(opts, d1_operation: {:query, sql, params})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: %Cloudflareq.D1.Result{} = result}} ->
        {:ok, result}

      {:ok, %Req.Response{body: {:error, _} = error}} ->
        error

      {:error, exception} ->
        {:error, exception}
    end
  end

  # -- Request step --

  defp run(%Req.Request{} = req) do
    case req.options[:d1_operation] do
      nil ->
        req

      operation ->
        req
        |> Cloudflareq.put_auth()
        |> configure_request(operation)
        |> Req.Request.append_response_steps(d1_handle_response: &handle_response/1)
    end
  end

  defp configure_request(req, :list_databases) do
    Req.merge(req, method: :get, url: d1_url(req, ""))
  end

  defp configure_request(req, {:list_databases_page, query_opts}) do
    params =
      query_opts
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    opts = [method: :get, url: d1_url(req, "")]
    opts = if map_size(params) > 0, do: Keyword.put(opts, :params, params), else: opts
    Req.merge(req, opts)
  end

  defp configure_request(req, {:create_database, name}) do
    Req.merge(req, method: :post, url: d1_url(req, ""), json: %{"name" => name})
  end

  defp configure_request(req, {:get_database, database_id}) do
    Req.merge(req, method: :get, url: d1_url(req, "/#{database_id}"))
  end

  defp configure_request(req, {:delete_database, database_id}) do
    Req.merge(req, method: :delete, url: d1_url(req, "/#{database_id}"))
  end

  defp configure_request(req, {:batch, queries}) do
    database_id = req.options[:database_id] || raise "missing required option :database_id"
    format = req.options[:d1_result_format] || :object
    endpoint = if format == :raw, do: "raw", else: "query"

    batch =
      Enum.map(queries, fn
        {sql, params} -> %{"sql" => sql, "params" => params}
        sql when is_binary(sql) -> %{"sql" => sql, "params" => []}
      end)

    Req.merge(req,
      method: :post,
      url: d1_url(req, "/#{database_id}/#{endpoint}"),
      json: %{"batch" => batch}
    )
  end

  defp configure_request(req, {:query, sql, params}) do
    database_id = req.options[:database_id] || raise "missing required option :database_id"
    format = req.options[:d1_result_format] || :object
    endpoint = if format == :raw, do: "raw", else: "query"

    Req.merge(req,
      method: :post,
      url: d1_url(req, "/#{database_id}/#{endpoint}"),
      json: %{"sql" => sql, "params" => params}
    )
  end

  defp d1_url(req, path) do
    account_id = req.options[:cf_account_id] || raise "missing required option :cf_account_id"
    "#{Cloudflareq.base_url(account_id)}/d1/database#{path}"
  end

  # -- Response step --

  defp handle_response({request, %Req.Response{status: status, body: body} = response})
       when status in 200..299 and is_map(body) do
    result_info = body["result_info"]

    case Cloudflareq.unwrap_response(body) do
      {:ok, result} ->
        transformed = transform_result(request, result, result_info)
        {request, %{response | body: transformed}}

      {:error, errors} ->
        {request, %{response | body: {:error, errors}}}
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
    case request.options[:d1_operation] do
      {:query, _, _} ->
        result |> List.first() |> build_result()

      {:batch, _} ->
        Enum.map(result, &build_result/1)

      :list_databases ->
        Enum.map(result, &Cloudflareq.Database.new/1)

      {:list_databases_page, _} ->
        databases = Enum.map(result, &Cloudflareq.Database.new/1)
        %{databases: databases, next_page: next_page(result_info)}

      _ ->
        result
    end
  end

  defp transform_result(request, result, _result_info) when is_map(result) do
    case request.options[:d1_operation] do
      {:create_database, _} -> Cloudflareq.Database.new(result)
      {:get_database, _} -> Cloudflareq.Database.new(result)
      _ -> result
    end
  end

  defp transform_result(_request, result, _result_info), do: result

  defp next_page(%{"page" => page, "total_count" => total, "per_page" => per_page})
       when page * per_page < total,
       do: page + 1

  defp next_page(_), do: nil

  defp build_result(%{"results" => rows, "meta" => meta} = item) do
    %Cloudflareq.D1.Result{
      success: item["success"],
      rows: rows,
      meta: normalize_meta(meta)
    }
  end

  defp build_result(item), do: item

  defp normalize_meta(meta) when is_map(meta) do
    %{
      duration: meta["duration"],
      rows_read: meta["rows_read"],
      rows_written: meta["rows_written"],
      changes: meta["changes"],
      last_row_id: meta["last_row_id"],
      size_after: meta["size_after"]
    }
  end
end
