defmodule Cloudflareq.StreamTest do
  use ExUnit.Case, async: true

  test "single page with nil cursor emits all items and halts" do
    stream =
      Cloudflareq.Stream.pages(fn nil ->
        {:ok, {[:a, :b, :c], nil}}
      end)

    assert Enum.to_list(stream) == [:a, :b, :c]
  end

  test "single page with empty string cursor emits all items and halts" do
    stream =
      Cloudflareq.Stream.pages(fn nil ->
        {:ok, {[:a], ""}}
      end)

    assert Enum.to_list(stream) == [:a]
  end

  test "multiple pages chains through cursors" do
    stream =
      Cloudflareq.Stream.pages(fn
        nil -> {:ok, {[1, 2], "page2"}}
        "page2" -> {:ok, {[3, 4], "page3"}}
        "page3" -> {:ok, {[5], nil}}
      end)

    assert Enum.to_list(stream) == [1, 2, 3, 4, 5]
  end

  test "error on first page emits error and halts" do
    stream =
      Cloudflareq.Stream.pages(fn nil ->
        {:error, :boom}
      end)

    assert Enum.to_list(stream) == [{:error, :boom}]
  end

  test "error on second page emits first page items then error" do
    stream =
      Cloudflareq.Stream.pages(fn
        nil -> {:ok, {[:a, :b], "next"}}
        "next" -> {:error, :timeout}
      end)

    assert Enum.to_list(stream) == [:a, :b, {:error, :timeout}]
  end

  test "empty first page with nil cursor emits nothing" do
    stream =
      Cloudflareq.Stream.pages(fn nil ->
        {:ok, {[], nil}}
      end)

    assert Enum.to_list(stream) == []
  end

  test "stream is lazy -- stops fetching after take" do
    test_pid = self()

    stream =
      Cloudflareq.Stream.pages(fn
        nil ->
          send(test_pid, :fetched_page_1)
          {:ok, {[1, 2, 3], "next"}}

        "next" ->
          send(test_pid, :fetched_page_2)
          {:ok, {[4, 5, 6], nil}}
      end)

    assert stream |> Stream.take(2) |> Enum.to_list() == [1, 2]
    assert_received :fetched_page_1
    refute_received :fetched_page_2
  end
end
