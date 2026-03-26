defmodule Cloudflareq.QueuesTest do
  use ExUnit.Case, async: true

  @queue_response %{
    "queue_id" => "q-1",
    "queue_name" => "my-queue",
    "created_on" => "2024-01-01T00:00:00Z",
    "modified_on" => "2024-02-01T00:00:00Z",
    "consumers_total_count" => 1,
    "producers_total_count" => 2,
    "settings" => %{
      "delivery_delay" => 0,
      "delivery_paused" => false,
      "message_retention_period" => 345_600
    }
  }

  @consumer_response %{
    "consumer_id" => "c-1",
    "type" => "http_pull",
    "script_name" => nil,
    "queue_name" => "my-queue",
    "dead_letter_queue" => nil,
    "created_on" => "2024-01-01T00:00:00Z",
    "settings" => %{
      "batch_size" => 10,
      "max_retries" => 3,
      "retry_delay" => 5,
      "visibility_timeout_ms" => 30_000
    }
  }

  # -- Queue CRUD --

  test "list_queues returns a list of Queue structs" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path =~ ~r|/queues$|

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [@queue_response]
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, [%Cloudflareq.Queues.Queue{} = q]} = Cloudflareq.Queues.list_queues(req)
    assert q.queue_id == "q-1"
    assert q.queue_name == "my-queue"
    assert q.settings.delivery_delay == 0
    assert q.settings.message_retention_period == 345_600
  end

  test "create_queue creates a new queue" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"queue_name" => "new-queue"} = Jason.decode!(body)

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{@queue_response | "queue_name" => "new-queue"}
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.Queues.Queue{queue_name: "new-queue"}} =
             Cloudflareq.Queues.create_queue(req, "new-queue")
  end

  test "get_queue returns queue details" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path =~ "/queues/q-1"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => @queue_response
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.Queues.Queue{queue_id: "q-1"}} =
             Cloudflareq.Queues.get_queue(req, "q-1")
  end

  test "update_queue updates queue settings" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path =~ "/queues/q-1"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["queue_name"] == "renamed-queue"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{@queue_response | "queue_name" => "renamed-queue"}
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.Queues.Queue{queue_name: "renamed-queue"}} =
             Cloudflareq.Queues.update_queue(req, "q-1", queue_name: "renamed-queue")
  end

  test "delete_queue deletes a queue" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path =~ "/queues/q-1"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert :ok = Cloudflareq.Queues.delete_queue(req, "q-1")
  end

  # -- Consumer management --

  test "list_consumers returns consumer structs" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path =~ "/queues/q-1/consumers"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [@consumer_response]
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, [%Cloudflareq.Queues.Consumer{} = c]} =
             Cloudflareq.Queues.list_consumers(req, "q-1")

    assert c.consumer_id == "c-1"
    assert c.type == "http_pull"
    assert c.settings.batch_size == 10
    assert c.settings.visibility_timeout_ms == 30_000
  end

  test "create_consumer creates a consumer" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path =~ "/queues/q-1/consumers"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["type"] == "http_pull"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => @consumer_response
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.Queues.Consumer{type: "http_pull"}} =
             Cloudflareq.Queues.create_consumer(req, "q-1",
               type: "http_pull",
               settings: %{batch_size: 10}
             )
  end

  test "update_consumer updates a consumer" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path =~ "/queues/q-1/consumers/c-1"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => @consumer_response
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.Queues.Consumer{}} =
             Cloudflareq.Queues.update_consumer(req, "q-1", "c-1",
               type: "http_pull",
               settings: %{batch_size: 20}
             )
  end

  test "delete_consumer deletes a consumer" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path =~ "/queues/q-1/consumers/c-1"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert :ok = Cloudflareq.Queues.delete_consumer(req, "q-1", "c-1")
  end

  # -- Message operations --

  test "send_message sends a message" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path =~ "/queues/q-1/messages"
      refute conn.request_path =~ "/batch"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["body"] == "hello"
      assert decoded["content_type"] == "text"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert :ok = Cloudflareq.Queues.send_message(req, "q-1", "hello", content_type: "text")
  end

  test "send_message_batch sends multiple messages" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path =~ "/queues/q-1/messages/batch"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert length(decoded["messages"]) == 2

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    messages = [
      [body: %{event: "signup"}, content_type: "json"],
      [body: "plain text", content_type: "text"]
    ]

    assert :ok = Cloudflareq.Queues.send_message_batch(req, "q-1", messages)
  end

  test "pull_messages returns messages with lease_ids" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path =~ "/queues/q-1/messages/pull"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["batch_size"] == 5

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "messages" => [
            %{
              "id" => "m-1",
              "body" => %{"event" => "signup"},
              "lease_id" => "lease-1",
              "attempts" => 1,
              "metadata" => nil,
              "timestamp_ms" => 1_700_000_000_000
            },
            %{
              "id" => "m-2",
              "body" => "hello",
              "lease_id" => "lease-2",
              "attempts" => 1,
              "metadata" => nil,
              "timestamp_ms" => 1_700_000_001_000
            }
          ],
          "message_backlog_count" => 10
        }
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %{messages: messages, message_backlog_count: 10}} =
             Cloudflareq.Queues.pull_messages(req, "q-1", batch_size: 5)

    assert [%Cloudflareq.Queues.Message{} = m1, %Cloudflareq.Queues.Message{} = m2] = messages
    assert m1.id == "m-1"
    assert m1.lease_id == "lease-1"
    assert m1.body == %{"event" => "signup"}
    assert m2.id == "m-2"
    assert m2.body == "hello"
  end

  test "ack_messages acknowledges and retries messages" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path =~ "/queues/q-1/messages/ack"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert length(decoded["acks"]) == 1
      assert length(decoded["retries"]) == 1

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "ackCount" => 1,
          "retryCount" => 1,
          "warnings" => []
        }
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.Queues.AckResult{} = result} =
             Cloudflareq.Queues.ack_messages(req, "q-1",
               acks: [%{lease_id: "lease-1"}],
               retries: [%{lease_id: "lease-2", delay_seconds: 10}]
             )

    assert result.ack_count == 1
    assert result.retry_count == 1
  end

  # -- Error handling and auth --

  test "returns structured errors on API failure" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{
        "success" => false,
        "errors" => [%{"code" => 1001, "message" => "queue not found"}],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:error,
            %Cloudflareq.Error{
              errors: [%Cloudflareq.ErrorData{code: 1001, message: "queue not found"}]
            }} =
             Cloudflareq.Queues.get_queue(req, "nonexistent")
  end

  test "sets bearer token auth header" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => []
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    Cloudflareq.Queues.list_queues(req)
  end

  test "attach/2 composes with an existing Req.Request" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [@queue_response]
      })
    end)

    req =
      Req.new(
        plug: {Req.Test, __MODULE__},
        retry: false
      )
      |> Cloudflareq.Queues.attach(cf_account_id: "test-account", cf_api_token: "test-token")

    assert {:ok, [%Cloudflareq.Queues.Queue{queue_name: "my-queue"}]} =
             Cloudflareq.Queues.list_queues(req)
  end

  test "stream_queues streams across multiple pages" do
    queue_a = %{@queue_response | "queue_id" => "q-a", "queue_name" => "queue-a"}
    queue_b = %{@queue_response | "queue_id" => "q-b", "queue_name" => "queue-b"}

    Req.Test.stub(__MODULE__, fn conn ->
      params = Plug.Conn.fetch_query_params(conn).query_params

      {queues, result_info} =
        case params["page"] do
          "1" ->
            {[queue_a], %{"page" => 1, "per_page" => 1, "total_count" => 2, "count" => 1}}

          "2" ->
            {[queue_b], %{"page" => 2, "per_page" => 1, "total_count" => 2, "count" => 1}}
        end

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => queues,
        "result_info" => result_info
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    queues = Cloudflareq.Queues.stream_queues(req, per_page: 1) |> Enum.to_list()

    assert [
             %Cloudflareq.Queues.Queue{queue_name: "queue-a"},
             %Cloudflareq.Queues.Queue{queue_name: "queue-b"}
           ] = queues
  end

  test "stream_queues with single page" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [@queue_response],
        "result_info" => %{"page" => 1, "per_page" => 20, "total_count" => 1, "count" => 1}
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert [%Cloudflareq.Queues.Queue{queue_name: "my-queue"}] =
             Cloudflareq.Queues.stream_queues(req) |> Enum.to_list()
  end

  test "stream_queues halts on error" do
    Req.Test.stub(__MODULE__, fn conn ->
      params = Plug.Conn.fetch_query_params(conn).query_params

      case params["page"] do
        "1" ->
          Req.Test.json(conn, %{
            "success" => true,
            "errors" => [],
            "messages" => [],
            "result" => [@queue_response],
            "result_info" => %{"page" => 1, "per_page" => 1, "total_count" => 2, "count" => 1}
          })

        "2" ->
          conn
          |> Plug.Conn.put_status(500)
          |> Req.Test.json(%{
            "success" => false,
            "errors" => [%{"code" => 10000, "message" => "internal error"}],
            "messages" => [],
            "result" => nil
          })
      end
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    results = Cloudflareq.Queues.stream_queues(req, per_page: 1) |> Enum.to_list()
    assert [%Cloudflareq.Queues.Queue{}, {:error, %Cloudflareq.Error{}}] = results
  end

  test "stream_consumers streams across multiple pages" do
    consumer_a = %{@consumer_response | "consumer_id" => "c-a"}
    consumer_b = %{@consumer_response | "consumer_id" => "c-b"}

    Req.Test.stub(__MODULE__, fn conn ->
      params = Plug.Conn.fetch_query_params(conn).query_params

      {consumers, result_info} =
        case params["page"] do
          "1" ->
            {[consumer_a], %{"page" => 1, "per_page" => 1, "total_count" => 2, "count" => 1}}

          "2" ->
            {[consumer_b], %{"page" => 2, "per_page" => 1, "total_count" => 2, "count" => 1}}
        end

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => consumers,
        "result_info" => result_info
      })
    end)

    req =
      Cloudflareq.Queues.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    consumers = Cloudflareq.Queues.stream_consumers(req, "q-1", per_page: 1) |> Enum.to_list()

    assert [
             %Cloudflareq.Queues.Consumer{consumer_id: "c-a"},
             %Cloudflareq.Queues.Consumer{consumer_id: "c-b"}
           ] =
             consumers
  end
end
