defmodule Cloudflareq.R2.TempCredentials do
  @moduledoc """
  A struct representing temporary R2 S3-compatible credentials.

  These credentials can be passed directly to `Cloudflareq.R2.s3/2` to create
  a `Req.Request` configured for R2 object operations via `ReqS3`.

  ## Fields

    * `:access_key_id` - the temporary access key ID.
    * `:secret_access_key` - the temporary secret access key.
    * `:session_token` - the session token for request signing.
  """

  defstruct [:access_key_id, :secret_access_key, :session_token]

  @type t :: %__MODULE__{
          access_key_id: String.t() | nil,
          secret_access_key: String.t() | nil,
          session_token: String.t() | nil
        }

  @doc """
  Creates a new `Cloudflareq.R2.TempCredentials` struct from a Cloudflare API response map.
  """
  def new(%{} = map) do
    %__MODULE__{
      access_key_id: map["accessKeyId"],
      secret_access_key: map["secretAccessKey"],
      session_token: map["sessionToken"]
    }
  end
end
