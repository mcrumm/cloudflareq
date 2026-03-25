defmodule Cloudflareq do
  @moduledoc """
  Shared utilities for `Req` plugins that interact with the Cloudflare API.

  ## Shared Options

    * `:cf_account_id` - Required. The Cloudflare account ID.
    * `:cf_api_token` - The Cloudflare API token. When set, the token is sent
      as a bearer token in the `Authorization` header.
  """

  @base_url "https://api.cloudflare.com/client/v4"

  @shared_options [:cf_account_id, :cf_api_token]

  @doc """
  Returns the list of shared option keys.
  """
  def shared_options, do: @shared_options

  @doc """
  Returns the Cloudflare API base URL for the given `account_id`.
  """
  def base_url(account_id) do
    "#{@base_url}/accounts/#{account_id}"
  end

  @doc """
  Adds bearer token authentication to the request if `:cf_api_token` is set.
  """
  def put_auth(%Req.Request{} = request) do
    case request.options[:cf_api_token] do
      nil -> request
      token -> Req.Request.merge_options(request, auth: {:bearer, token})
    end
  end

  @doc """
  Unwraps a Cloudflare API response body.

  Returns `{:ok, result}` on success or `{:error, errors}` with a list of
  `Cloudflareq.Error` structs on failure.
  """
  def unwrap_response(%{"success" => true, "result" => result}) do
    {:ok, result}
  end

  def unwrap_response(%{"success" => false, "errors" => errors}) do
    {:error, Enum.map(errors, &Cloudflareq.Error.new/1)}
  end
end
