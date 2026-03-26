defmodule Cloudflareq.WorkersTest do
  use ExUnit.Case, async: true

  @script_response %{
    "id" => "my-worker",
    "etag" => "abc123",
    "handlers" => ["fetch"],
    "has_assets" => false,
    "has_modules" => true,
    "usage_model" => "standard",
    "compatibility_date" => "2024-01-01",
    "compatibility_flags" => [],
    "created_on" => "2024-01-01T00:00:00Z",
    "modified_on" => "2024-03-01T00:00:00Z",
    "last_deployed_from" => "api",
    "logpush" => false,
    "startup_time_ms" => 5
  }

  test "list_scripts returns a list of Script structs" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path =~ ~r|/workers/scripts$|

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [@script_response, %{@script_response | "id" => "other-worker"}]
      })
    end)

    req =
      Cloudflareq.Workers.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, [%Cloudflareq.Workers.Script{} = s1, %Cloudflareq.Workers.Script{} = s2]} =
             Cloudflareq.Workers.list_scripts(req)

    assert s1.id == "my-worker"
    assert s1.handlers == ["fetch"]
    assert s1.has_modules == true
    assert s1.startup_time_ms == 5
    assert s2.id == "other-worker"
  end

  test "get_script_content returns raw script content" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path =~ "/workers/scripts/my-worker/content/v2"

      conn
      |> Plug.Conn.put_resp_content_type("application/javascript")
      |> Plug.Conn.send_resp(200, "export default { fetch() { return new Response('ok') } }")
    end)

    req =
      Cloudflareq.Workers.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, content} = Cloudflareq.Workers.get_script_content(req, "my-worker")
    assert content =~ "export default"
  end

  test "upload_script sends multipart and returns Script struct" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path =~ "/workers/scripts/my-worker"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => @script_response
      })
    end)

    req =
      Cloudflareq.Workers.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    script_content = "export default { fetch() { return new Response('hello') } }"

    assert {:ok, %Cloudflareq.Workers.Script{} = script} =
             Cloudflareq.Workers.upload_script(req, "my-worker", script_content)

    assert script.id == "my-worker"
    assert script.has_modules == true
  end

  test "put_script_content uploads content only" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path =~ "/workers/scripts/my-worker/content"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => @script_response
      })
    end)

    req =
      Cloudflareq.Workers.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.Workers.Script{id: "my-worker"}} =
             Cloudflareq.Workers.put_script_content(req, "my-worker", "export default {}")
  end

  test "delete_script deletes a script" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path =~ "/workers/scripts/my-worker"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.Workers.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert :ok = Cloudflareq.Workers.delete_script(req, "my-worker")
  end

  test "delete_script with force option" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.query_string =~ "force=true"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.Workers.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert :ok = Cloudflareq.Workers.delete_script(req, "my-worker", force: true)
  end

  test "returns structured errors on API failure" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{
        "success" => false,
        "errors" => [%{"code" => 10007, "message" => "script not found"}],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.Workers.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:error,
            %Cloudflareq.Error{
              errors: [%Cloudflareq.ErrorData{code: 10007, message: "script not found"}]
            }} =
             Cloudflareq.Workers.list_scripts(req)
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
      Cloudflareq.Workers.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    Cloudflareq.Workers.list_scripts(req)
  end

  test "attach/2 composes with an existing Req.Request" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [@script_response]
      })
    end)

    req =
      Req.new(
        plug: {Req.Test, __MODULE__},
        retry: false
      )
      |> Cloudflareq.Workers.attach(cf_account_id: "test-account", cf_api_token: "test-token")

    assert {:ok, [%Cloudflareq.Workers.Script{id: "my-worker"}]} =
             Cloudflareq.Workers.list_scripts(req)
  end

  test "stream_scripts streams across multiple pages" do
    script_a = %{@script_response | "id" => "worker-a"}
    script_b = %{@script_response | "id" => "worker-b"}

    Req.Test.stub(__MODULE__, fn conn ->
      params = Plug.Conn.fetch_query_params(conn).query_params

      {scripts, result_info} =
        case params["page"] do
          "1" ->
            {[script_a], %{"page" => 1, "per_page" => 1, "total_count" => 2, "count" => 1}}

          "2" ->
            {[script_b], %{"page" => 2, "per_page" => 1, "total_count" => 2, "count" => 1}}
        end

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => scripts,
        "result_info" => result_info
      })
    end)

    req =
      Cloudflareq.Workers.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    scripts = Cloudflareq.Workers.stream_scripts(req, per_page: 1) |> Enum.to_list()

    assert [
             %Cloudflareq.Workers.Script{id: "worker-a"},
             %Cloudflareq.Workers.Script{id: "worker-b"}
           ] = scripts
  end

  test "stream_scripts with single page" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [@script_response],
        "result_info" => %{"page" => 1, "per_page" => 20, "total_count" => 1, "count" => 1}
      })
    end)

    req =
      Cloudflareq.Workers.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert [%Cloudflareq.Workers.Script{id: "my-worker"}] =
             Cloudflareq.Workers.stream_scripts(req) |> Enum.to_list()
  end

  test "stream_scripts halts on error" do
    Req.Test.stub(__MODULE__, fn conn ->
      params = Plug.Conn.fetch_query_params(conn).query_params

      case params["page"] do
        "1" ->
          Req.Test.json(conn, %{
            "success" => true,
            "errors" => [],
            "messages" => [],
            "result" => [@script_response],
            "result_info" => %{"page" => 1, "per_page" => 1, "total_count" => 2, "count" => 1}
          })

        "2" ->
          conn
          |> Plug.Conn.put_status(403)
          |> Req.Test.json(%{
            "success" => false,
            "errors" => [%{"code" => 10000, "message" => "forbidden"}],
            "messages" => [],
            "result" => nil
          })
      end
    end)

    req =
      Cloudflareq.Workers.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    results = Cloudflareq.Workers.stream_scripts(req, per_page: 1) |> Enum.to_list()
    assert [%Cloudflareq.Workers.Script{}, {:error, %Cloudflareq.Error{}}] = results
  end
end
