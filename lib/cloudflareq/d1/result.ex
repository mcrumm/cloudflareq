defmodule Cloudflareq.D1.Result do
  @moduledoc """
  A struct representing the result of a D1 query.

  ## Fields

    * `:success` - whether the query was successful.
    * `:rows` - the result rows as a list of maps (object format) or a map (raw format).
    * `:meta` - query metadata including `:duration`, `:rows_read`, `:rows_written`,
      `:changes`, `:last_row_id`, and `:size_after`.
  """

  defstruct [:rows, :meta, :success]

  @type t :: %__MODULE__{
          success: boolean(),
          rows: [map()] | map(),
          meta: map()
        }
end
