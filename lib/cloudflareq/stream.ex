defmodule Cloudflareq.Stream do
  @moduledoc false

  @doc """
  Returns a `Stream` that lazily fetches pages of items.

  `fetch_page` is a function of arity 1 that receives the current cursor
  (or `nil` for the first page) and must return one of:

    * `{:ok, {items, next_cursor}}` — a page of items and the cursor for
      the next page. A `next_cursor` of `nil` or `""` means no more pages.
    * `{:error, reason}` — an error that halts the stream.

  Items are emitted individually. On error, `{:error, reason}` is emitted
  as the final element before the stream halts.
  """
  def pages(fetch_page) when is_function(fetch_page, 1) do
    Stream.resource(
      fn -> :init end,
      fn
        :halt ->
          {:halt, :done}

        :init ->
          fetch_and_emit(fetch_page, nil)

        {:next, cursor} ->
          fetch_and_emit(fetch_page, cursor)
      end,
      fn _state -> :ok end
    )
  end

  defp fetch_and_emit(fetch_page, cursor) do
    case fetch_page.(cursor) do
      {:ok, {items, nil}} ->
        {items, :halt}

      {:ok, {items, ""}} ->
        {items, :halt}

      {:ok, {items, next_cursor}} ->
        {items, {:next, next_cursor}}

      {:error, reason} ->
        {[{:error, reason}], :halt}
    end
  end
end
