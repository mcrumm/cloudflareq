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
  Verifies a Cloudflare API token is valid and active.

  Issues a GET request to `https://api.cloudflare.com/client/v4/user/tokens/verify`.

  Returns `{:ok, %Cloudflareq.Token{}}` when the token is active, or
  `{:error, exception}` on failure.

  ## Examples

      {:ok, %Cloudflareq.Token{status: "active"}} = Cloudflareq.verify_token("my-token")

  """
  @spec verify_token(String.t(), keyword()) :: {:ok, Cloudflareq.Token.t()} | {:error, Exception.t()}
  def verify_token(api_token, opts \\ []) when is_binary(api_token) do
    url = @base_url <> "/user/tokens/verify"

    case Req.request([method: :get, url: url, auth: {:bearer, api_token}] ++ opts) do
      {:ok, %Req.Response{body: body}} when is_map(body) ->
        case unwrap_response(body) do
          {:ok, result} ->
            token = Cloudflareq.Token.new(result)

            case token.status do
              "active" -> {:ok, token}
              status when status in ["disabled", "expired"] -> {:error, %Cloudflareq.TokenError{status: status}}
            end

          {:error, errors} ->
            message = Enum.map_join(errors, ", ", &to_string/1)
            {:error, RuntimeError.exception(message)}
        end

      {:error, exception} ->
        {:error, exception}
    end
  end

  @doc """
  Bang variant of `verify_token/1`.

  Returns the `%Cloudflareq.Token{}` directly on success, or raises on error.

  ## Examples

      %Cloudflareq.Token{status: "active"} = Cloudflareq.verify_token!("my-token")

  """
  @spec verify_token!(String.t(), keyword()) :: Cloudflareq.Token.t()
  def verify_token!(api_token, opts \\ []) when is_binary(api_token) do
    case verify_token(api_token, opts) do
      {:ok, token} -> token
      {:error, exception} -> raise exception
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
