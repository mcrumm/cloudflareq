defmodule Cloudflareq.Workers.Script do
  @moduledoc """
  A struct representing a Cloudflare Workers script.

  ## Fields

    * `:id` - the script name/identifier.
    * `:etag` - the entity tag.
    * `:handlers` - list of handler types, e.g. `["fetch"]`.
    * `:has_assets` - whether the script has associated assets.
    * `:has_modules` - whether the script uses ES modules format.
    * `:usage_model` - the usage model, e.g. `"standard"`.
    * `:compatibility_date` - the compatibility date string.
    * `:compatibility_flags` - list of compatibility flags.
    * `:created_on` - when the script was created.
    * `:modified_on` - when the script was last modified.
    * `:last_deployed_from` - where the script was last deployed from.
    * `:logpush` - whether logpush is enabled.
    * `:startup_time_ms` - startup time in milliseconds.
  """

  defstruct [
    :id,
    :etag,
    :handlers,
    :has_assets,
    :has_modules,
    :usage_model,
    :compatibility_date,
    :compatibility_flags,
    :created_on,
    :modified_on,
    :last_deployed_from,
    :logpush,
    :startup_time_ms
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          etag: String.t() | nil,
          handlers: [String.t()] | nil,
          has_assets: boolean() | nil,
          has_modules: boolean() | nil,
          usage_model: String.t() | nil,
          compatibility_date: String.t() | nil,
          compatibility_flags: [String.t()] | nil,
          created_on: DateTime.t() | nil,
          modified_on: DateTime.t() | nil,
          last_deployed_from: String.t() | nil,
          logpush: boolean() | nil,
          startup_time_ms: number() | nil
        }

  @doc false
  def new(%{} = map) do
    %__MODULE__{
      id: map["id"],
      etag: map["etag"],
      handlers: map["handlers"],
      has_assets: map["has_assets"],
      has_modules: map["has_modules"],
      usage_model: map["usage_model"],
      compatibility_date: map["compatibility_date"],
      compatibility_flags: map["compatibility_flags"],
      created_on: Cloudflareq.parse_datetime(map["created_on"]),
      modified_on: Cloudflareq.parse_datetime(map["modified_on"]),
      last_deployed_from: map["last_deployed_from"],
      logpush: map["logpush"],
      startup_time_ms: map["startup_time_ms"]
    }
  end
end
