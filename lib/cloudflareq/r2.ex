defmodule Cloudflareq.R2 do
  @moduledoc """
  A `Req` plugin for the [Cloudflare R2](https://developers.cloudflare.com/r2/) HTTP API.

  ## Options

    * `:cf_account_id` - Required. The Cloudflare account ID.
    * `:cf_api_token` - The Cloudflare API token. When set, the token is sent
      as a bearer token in the `Authorization` header.
    * `:bucket_name` - The R2 bucket name. Required for bucket-scoped operations.
    * `:r2_jurisdiction` - Optional. The jurisdiction for R2 operations, e.g. `"eu"`
      or `"fedramp"`. When set, the `cf-r2-jurisdiction` header is added to requests.

  ## Examples

      # Create a client
      req = Cloudflareq.R2.new(cf_account_id: "acct_id", cf_api_token: "token")

      # List buckets
      {:ok, %{buckets: buckets, cursor: cursor}} = Cloudflareq.R2.list_buckets(req)

      # Create a bucket
      {:ok, bucket} = Cloudflareq.R2.create_bucket(req, "my-bucket")

      # Bridge to S3 for object operations (requires req_s3)
      s3 = Cloudflareq.R2.s3(req, access_key_id: "key", secret_access_key: "secret")
      Req.put!(s3, url: "s3://my-bucket/hello.txt", body: "Hello!")
  """

  @options Cloudflareq.shared_options() ++ [:bucket_name, :r2_jurisdiction, :r2_operation]

  @doc """
  Creates a new `Req.Request` with the R2 plugin attached.

  Accepts all R2 options as well as any standard `Req` options.

  ## Examples

      req = Cloudflareq.R2.new(cf_account_id: "acct_id", cf_api_token: "token")
  """
  def new(opts \\ []) do
    {plugin_opts, req_opts} = Keyword.split(opts, @options)
    Req.new(req_opts) |> attach(plugin_opts)
  end

  @doc """
  Attaches the R2 plugin to an existing `Req.Request`.

  ## Examples

      req = Req.new() |> Cloudflareq.R2.attach(cf_account_id: "acct_id", cf_api_token: "token")
  """
  def attach(%Req.Request{} = req, opts \\ []) do
    req
    |> Req.Request.prepend_request_steps(r2_run: &run/1)
    |> Req.Request.register_options(@options)
    |> Req.Request.merge_options(opts)
  end

  @doc """
  Lists all R2 buckets for the account.

  Returns `{:ok, %{buckets: [%Cloudflareq.R2.Bucket{}], cursor: cursor}}` or `{:error, reason}`.
  The `cursor` is `nil` when there are no more pages.

  ## Options

  Pagination and filtering options can be passed in `opts`:

    * `:cursor` - cursor for the next page of results.
    * `:per_page` - number of results per page.
    * `:name_contains` - filter buckets by name substring.
    * `:start_after` - return buckets after this name.
    * `:order` - sort order, e.g. `"name"`.
    * `:direction` - sort direction, `"asc"` or `"desc"`.

  ## Examples

      {:ok, %{buckets: buckets}} = Cloudflareq.R2.list_buckets(req)
  """
  def list_buckets(req, opts \\ []) do
    {query_opts, opts} =
      Keyword.split(opts, [:cursor, :per_page, :name_contains, :start_after, :order, :direction])

    opts = Keyword.merge(opts, r2_operation: {:list_buckets, query_opts})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Returns a `Stream` that lazily paginates through all R2 buckets.

  Each element is a `%Cloudflareq.R2.Bucket{}` struct. On error,
  `{:error, reason}` is emitted as the final element.

  Accepts the same filtering options as `list_buckets/2`.

  ## Examples

      Cloudflareq.R2.stream_buckets(req) |> Enum.to_list()
      Cloudflareq.R2.stream_buckets(req, per_page: 10) |> Stream.take(50) |> Enum.to_list()
  """
  def stream_buckets(req, opts \\ []) do
    Cloudflareq.Stream.pages(fn cursor ->
      opts = if cursor, do: Keyword.put(opts, :cursor, cursor), else: opts

      case list_buckets(req, opts) do
        {:ok, %{buckets: buckets, cursor: next}} -> {:ok, {buckets, next}}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  @doc """
  Creates a new R2 bucket with the given `name`.

  Returns `{:ok, bucket}` with the created `Cloudflareq.R2.Bucket` struct,
  or `{:error, reason}`.

  ## Options

    * `:location_hint` - a location hint for the bucket, e.g. `"eu"`.
    * `:storage_class` - the default storage class, e.g. `"InfrequentAccess"`.

  ## Examples

      {:ok, bucket} = Cloudflareq.R2.create_bucket(req, "my-bucket")
      {:ok, bucket} = Cloudflareq.R2.create_bucket(req, "eu-bucket", location_hint: "eu")
  """
  def create_bucket(req, name, opts \\ []) do
    {create_opts, opts} = Keyword.split(opts, [:location_hint, :storage_class])
    opts = Keyword.merge(opts, r2_operation: {:create_bucket, name, create_opts})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Gets details for an R2 bucket by its `bucket_name`.

  Returns `{:ok, bucket}` with the `Cloudflareq.R2.Bucket` struct,
  or `{:error, reason}`.

  ## Examples

      {:ok, bucket} = Cloudflareq.R2.get_bucket(req, "my-bucket")
  """
  def get_bucket(req, bucket_name, opts \\ []) do
    opts = Keyword.merge(opts, r2_operation: {:get_bucket, bucket_name})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Deletes an R2 bucket by its `bucket_name`.

  Returns `:ok` on success, or `{:error, reason}`.

  ## Examples

      :ok = Cloudflareq.R2.delete_bucket(req, "my-bucket")
  """
  def delete_bucket(req, bucket_name, opts \\ []) do
    opts = Keyword.merge(opts, r2_operation: {:delete_bucket, bucket_name})

    case Req.request(req, opts) do
      {:ok, _response} -> :ok
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Gets the lifecycle rules for an R2 bucket.

  Returns `{:ok, result}` with the lifecycle configuration map,
  or `{:error, reason}`.

  ## Examples

      {:ok, %{"rules" => rules}} = Cloudflareq.R2.get_lifecycle(req, "my-bucket")
  """
  def get_lifecycle(req, bucket_name, opts \\ []) do
    opts = Keyword.merge(opts, r2_operation: {:get_lifecycle, bucket_name})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Sets the lifecycle rules for an R2 bucket.

  `rules` is a list of lifecycle rule maps.

  Returns `{:ok, result}` or `{:error, reason}`.

  ## Examples

      rules = [%{"id" => "cleanup", "conditions" => %{"prefix" => "tmp/"}, "actions" => %{"type" => "Delete", "afterDays" => 7}}]
      {:ok, _} = Cloudflareq.R2.put_lifecycle(req, "my-bucket", rules)
  """
  def put_lifecycle(req, bucket_name, rules, opts \\ []) when is_list(rules) do
    opts = Keyword.merge(opts, r2_operation: {:put_lifecycle, bucket_name, rules})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Gets the CORS rules for an R2 bucket.

  Returns `{:ok, result}` with the CORS configuration map,
  or `{:error, reason}`.

  ## Examples

      {:ok, %{"rules" => rules}} = Cloudflareq.R2.get_cors(req, "my-bucket")
  """
  def get_cors(req, bucket_name, opts \\ []) do
    opts = Keyword.merge(opts, r2_operation: {:get_cors, bucket_name})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Sets the CORS rules for an R2 bucket.

  `rules` is a list of CORS rule maps.

  Returns `{:ok, result}` or `{:error, reason}`.

  ## Examples

      rules = [%{"allowedOrigins" => ["*"], "allowedMethods" => ["GET", "PUT"]}]
      {:ok, _} = Cloudflareq.R2.put_cors(req, "my-bucket", rules)
  """
  def put_cors(req, bucket_name, rules, opts \\ []) when is_list(rules) do
    opts = Keyword.merge(opts, r2_operation: {:put_cors, bucket_name, rules})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Deletes the CORS configuration for an R2 bucket.

  Returns `:ok` on success, or `{:error, reason}`.

  ## Examples

      :ok = Cloudflareq.R2.delete_cors(req, "my-bucket")
  """
  def delete_cors(req, bucket_name, opts \\ []) do
    opts = Keyword.merge(opts, r2_operation: {:delete_cors, bucket_name})

    case Req.request(req, opts) do
      {:ok, _response} -> :ok
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Lists all event notification rules for an R2 bucket.

  Returns `{:ok, result}` with the notification configuration map,
  or `{:error, reason}`.

  ## Examples

      {:ok, config} = Cloudflareq.R2.list_event_notification_rules(req, "my-bucket")
  """
  def list_event_notification_rules(req, bucket_name, opts \\ []) do
    opts = Keyword.merge(opts, r2_operation: {:list_event_notification_rules, bucket_name})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Creates or updates an event notification rule for an R2 bucket on the given queue.

  `rules` is a list of rule maps (each with keys like `"prefix"`, `"suffix"`, `"actions"`, etc).
  The JSON body sent to the API is `%{"rules" => rules}`.

  Returns `{:ok, result}` or `{:error, reason}`.

  ## Examples

      rules = [%{"actions" => ["PutObject"], "prefix" => "images/"}]
      {:ok, _} = Cloudflareq.R2.put_event_notification_rule(req, "my-bucket", "queue-id", rules)
  """
  def put_event_notification_rule(req, bucket_name, queue_id, rules, opts \\ [])
      when is_list(rules) do
    opts =
      Keyword.merge(opts,
        r2_operation: {:put_event_notification_rule, bucket_name, queue_id, rules}
      )

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Deletes an event notification rule for an R2 bucket on the given queue.

  Returns `:ok` on success, or `{:error, reason}`.

  ## Examples

      :ok = Cloudflareq.R2.delete_event_notification_rule(req, "my-bucket", "queue-id")
  """
  def delete_event_notification_rule(req, bucket_name, queue_id, opts \\ []) do
    opts =
      Keyword.merge(opts,
        r2_operation: {:delete_event_notification_rule, bucket_name, queue_id}
      )

    case Req.request(req, opts) do
      {:ok, _response} -> :ok
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Creates temporary S3-compatible credentials for R2 object operations.

  Returns `{:ok, %Cloudflareq.R2.TempCredentials{}}` or `{:error, reason}`.

  The returned credentials can be passed directly to `s3/2` to create
  a `Req.Request` configured for R2 object operations via `ReqS3`.

  ## Params

    * `:bucket` - Required. The R2 bucket name.
    * `:parent_access_key_id` - Required. The parent R2 API token access key ID.
    * `:permission` - Required. One of `"object-read-write"`, `"object-read-only"`,
      or `"object-write-only"`.
    * `:ttl_seconds` - Required. The time-to-live in seconds for the credentials.
    * `:objects` - Optional. List of object keys to scope the credentials to.
    * `:prefixes` - Optional. List of key prefixes to scope the credentials to.

  ## Examples

      {:ok, creds} = Cloudflareq.R2.create_temp_credentials(req,
        bucket: "my-bucket",
        parent_access_key_id: "key",
        permission: "object-read-write",
        ttl_seconds: 900
      )

      s3 = Cloudflareq.R2.s3(req, creds)
  """
  def create_temp_credentials(req, params, opts \\ []) do
    params = if is_list(params), do: Map.new(params), else: params
    opts = Keyword.merge(opts, r2_operation: {:create_temp_credentials, params})

    case Req.request(req, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, exception}
    end
  end

  # -- Request step --

  defp run(%Req.Request{} = req) do
    case req.options[:r2_operation] do
      nil ->
        req

      operation ->
        req
        |> Cloudflareq.put_auth()
        |> put_jurisdiction_header()
        |> configure_request(operation)
        |> Req.Request.append_response_steps(r2_handle_response: &handle_response/1)
    end
  end

  defp put_jurisdiction_header(req) do
    case req.options[:r2_jurisdiction] do
      nil -> req
      jurisdiction -> Req.Request.put_header(req, "cf-r2-jurisdiction", jurisdiction)
    end
  end

  defp configure_request(req, {:list_buckets, query_opts}) do
    params =
      query_opts
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    opts = [method: :get, url: r2_url(req, "/buckets")]
    opts = if map_size(params) > 0, do: Keyword.put(opts, :params, params), else: opts
    Req.merge(req, opts)
  end

  defp configure_request(req, {:create_bucket, name, create_opts}) do
    json = %{"name" => name}
    json = maybe_put(json, "locationHint", Keyword.get(create_opts, :location_hint))
    json = maybe_put(json, "storageClass", Keyword.get(create_opts, :storage_class))
    Req.merge(req, method: :post, url: r2_url(req, "/buckets"), json: json)
  end

  defp configure_request(req, {:get_bucket, bucket_name}) do
    Req.merge(req, method: :get, url: r2_url(req, "/buckets/#{bucket_name}"))
  end

  defp configure_request(req, {:delete_bucket, bucket_name}) do
    Req.merge(req, method: :delete, url: r2_url(req, "/buckets/#{bucket_name}"))
  end

  defp configure_request(req, {:get_lifecycle, bucket_name}) do
    Req.merge(req, method: :get, url: r2_url(req, "/buckets/#{bucket_name}/lifecycle"))
  end

  defp configure_request(req, {:put_lifecycle, bucket_name, rules}) do
    Req.merge(req,
      method: :put,
      url: r2_url(req, "/buckets/#{bucket_name}/lifecycle"),
      json: %{"rules" => rules}
    )
  end

  defp configure_request(req, {:get_cors, bucket_name}) do
    Req.merge(req, method: :get, url: r2_url(req, "/buckets/#{bucket_name}/cors"))
  end

  defp configure_request(req, {:put_cors, bucket_name, rules}) do
    Req.merge(req,
      method: :put,
      url: r2_url(req, "/buckets/#{bucket_name}/cors"),
      json: %{"rules" => rules}
    )
  end

  defp configure_request(req, {:delete_cors, bucket_name}) do
    Req.merge(req, method: :delete, url: r2_url(req, "/buckets/#{bucket_name}/cors"))
  end

  defp configure_request(req, {:list_event_notification_rules, bucket_name}) do
    Req.merge(req, method: :get, url: event_notifications_url(req, bucket_name, ""))
  end

  defp configure_request(req, {:put_event_notification_rule, bucket_name, queue_id, rules}) do
    Req.merge(req,
      method: :put,
      url: event_notifications_url(req, bucket_name, "/queues/#{queue_id}"),
      json: %{"rules" => rules}
    )
  end

  defp configure_request(req, {:delete_event_notification_rule, bucket_name, queue_id}) do
    Req.merge(req,
      method: :delete,
      url: event_notifications_url(req, bucket_name, "/queues/#{queue_id}")
    )
  end

  defp configure_request(req, {:create_temp_credentials, params}) do
    json = %{
      "bucket" => params[:bucket],
      "parentAccessKeyId" => params[:parent_access_key_id],
      "permission" => params[:permission],
      "ttlSeconds" => params[:ttl_seconds]
    }

    json = maybe_put(json, "objects", params[:objects])
    json = maybe_put(json, "prefixes", params[:prefixes])
    Req.merge(req, method: :post, url: r2_url(req, "/temp-access-credentials"), json: json)
  end

  defp r2_url(req, path) do
    account_id = req.options[:cf_account_id] || raise "missing required option :cf_account_id"
    "#{Cloudflareq.base_url(account_id)}/r2#{path}"
  end

  defp event_notifications_url(req, bucket_name, path) do
    account_id = req.options[:cf_account_id] || raise "missing required option :cf_account_id"

    "#{Cloudflareq.base_url(account_id)}/event_notifications/r2/#{bucket_name}/configuration#{path}"
  end

  # -- Response step --

  defp handle_response({request, response}) do
    Cloudflareq.transform_response(request, response, &transform_result/3)
  end

  defp transform_result(request, result, result_info) do
    case request.options[:r2_operation] do
      {:list_buckets, _} ->
        buckets = Enum.map(result["buckets"] || [], &Cloudflareq.R2.Bucket.new/1)
        cursor = result_info && result_info["cursor"]
        %{buckets: buckets, cursor: cursor}

      {:create_bucket, _, _} when is_map(result) ->
        Cloudflareq.R2.Bucket.new(result)

      {:get_bucket, _} when is_map(result) ->
        Cloudflareq.R2.Bucket.new(result)

      {:create_temp_credentials, _} when is_map(result) ->
        Cloudflareq.R2.TempCredentials.new(result)

      _ ->
        result
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # -- ReqS3 bridge --

  if Code.ensure_loaded?(ReqS3) do
    @doc """
    Creates a `Req.Request` with `ReqS3` attached, configured for R2 object operations.

    The R2 S3 endpoint URL is automatically derived from the `cf_account_id`
    in the given request's options.

    Accepts either a keyword list with `:access_key_id` and `:secret_access_key`,
    or a `Cloudflareq.R2.TempCredentials` struct (as returned by `create_temp_credentials/3`).

    ## Examples

        # With static credentials
        s3 = Cloudflareq.R2.s3(req, access_key_id: "key", secret_access_key: "secret")
        Req.put!(s3, url: "s3://my-bucket/hello.txt", body: "Hello!")
        Req.get!(s3, url: "s3://my-bucket/hello.txt")

        # With temp credentials
        {:ok, creds} = Cloudflareq.R2.create_temp_credentials(req, ...)
        s3 = Cloudflareq.R2.s3(req, creds)
        Req.get!(s3, url: "s3://my-bucket/photo.jpg")
    """
    def s3(%Req.Request{} = req, %Cloudflareq.R2.TempCredentials{} = creds) do
      s3(req,
        access_key_id: creds.access_key_id,
        secret_access_key: creds.secret_access_key,
        session_token: creds.session_token
      )
    end

    def s3(%Req.Request{} = req, opts) when is_list(opts) do
      account_id = req.options[:cf_account_id] || raise "missing required option :cf_account_id"
      endpoint = "https://#{account_id}.r2.cloudflarestorage.com"

      s3_opts = [aws_endpoint_url_s3: endpoint]

      s3_opts =
        if opts[:access_key_id] do
          sigv4 = [
            service: :s3,
            access_key_id: opts[:access_key_id],
            secret_access_key: opts[:secret_access_key]
          ]

          sigv4 =
            if opts[:session_token],
              do: Keyword.put(sigv4, :token, opts[:session_token]),
              else: sigv4

          Keyword.put(s3_opts, :aws_sigv4, sigv4)
        else
          s3_opts
        end

      Req.new() |> ReqS3.attach(s3_opts)
    end

    @doc """
    Generates a presigned URL for an R2 object.

    When called with an s3-configured request (via `s3/2`), credentials and
    endpoint are read from the request automatically. Explicit opts always
    take precedence.

    Wraps `ReqS3.presign_url/1`.

    ## Options

    Accepts all options from `ReqS3.presign_url/1` except `:bucket`, `:key`,
    and `:endpoint_url` which are set automatically.

    ## Examples

        # With s3-configured request (credentials read from request)
        s3 = Cloudflareq.R2.s3(req, access_key_id: "key", secret_access_key: "secret")
        url = Cloudflareq.R2.presign_url(s3, "my-bucket", "photo.jpg")

        # Still works with explicit credentials
        url = Cloudflareq.R2.presign_url(req, "my-bucket", "photo.jpg",
          access_key_id: "key",
          secret_access_key: "secret"
        )
    """
    def presign_url(%Req.Request{} = req, bucket, key, opts \\ []) do
      sigv4 = req.options[:aws_sigv4]

      opts =
        if sigv4 do
          opts
          |> Keyword.put_new(:access_key_id, sigv4[:access_key_id])
          |> Keyword.put_new(:secret_access_key, sigv4[:secret_access_key])
        else
          opts
        end

      endpoint =
        cond do
          url = req.options[:aws_endpoint_url_s3] -> url
          id = req.options[:cf_account_id] -> "https://#{id}.r2.cloudflarestorage.com"
          true -> raise "missing :cf_account_id or :aws_endpoint_url_s3 on request"
        end

      opts
      |> Keyword.merge(bucket: bucket, key: key)
      |> Keyword.put_new(:endpoint_url, endpoint)
      |> ReqS3.presign_url()
    end

    @doc """
    Generates a presigned form for uploading to an R2 bucket.

    When called with an s3-configured request (via `s3/2`), credentials and
    endpoint are read from the request automatically. Explicit opts always
    take precedence.

    Wraps `ReqS3.presign_form/1`.

    ## Options

    Accepts all options from `ReqS3.presign_form/1` except `:bucket`, `:key`,
    and `:endpoint_url` which are set automatically.

    ## Examples

        # With s3-configured request (credentials read from request)
        s3 = Cloudflareq.R2.s3(req, access_key_id: "key", secret_access_key: "secret")
        form = Cloudflareq.R2.presign_form(s3, "my-bucket", "uploads/photo.jpg")

        # Still works with explicit credentials
        form = Cloudflareq.R2.presign_form(req, "my-bucket", "uploads/photo.jpg",
          access_key_id: "key",
          secret_access_key: "secret",
          max_size: 10_000_000,
          content_type: "image/jpeg"
        )
    """
    def presign_form(%Req.Request{} = req, bucket, key, opts \\ []) do
      sigv4 = req.options[:aws_sigv4]

      opts =
        if sigv4 do
          opts
          |> Keyword.put_new(:access_key_id, sigv4[:access_key_id])
          |> Keyword.put_new(:secret_access_key, sigv4[:secret_access_key])
        else
          opts
        end

      endpoint =
        cond do
          url = req.options[:aws_endpoint_url_s3] -> url
          id = req.options[:cf_account_id] -> "https://#{id}.r2.cloudflarestorage.com"
          true -> raise "missing :cf_account_id or :aws_endpoint_url_s3 on request"
        end

      opts
      |> Keyword.merge(bucket: bucket, key: key)
      |> Keyword.put_new(:endpoint_url, endpoint)
      |> ReqS3.presign_form()
    end
  end
end
