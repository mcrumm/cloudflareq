defmodule Cloudflareq.D1Test do
  use ExUnit.Case, async: true

  test "executes a query and returns a result" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [
          %{
            "success" => true,
            "results" => [%{"1" => 1}],
            "meta" => %{
              "duration" => 0.01,
              "rows_read" => 1,
              "rows_written" => 0,
              "changes" => 0,
              "last_row_id" => 0,
              "size_after" => 8192
            }
          }
        ]
      })
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        database_id: "test-db-id",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.D1.Result{} = result} = Cloudflareq.D1.query(req, "SELECT 1")
    assert result.rows == [%{"1" => 1}]
    assert result.meta.duration == 0.01
    assert result.meta.rows_read == 1
  end

  test "sends params in the request body" do
    Req.Test.stub(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded == %{"sql" => "SELECT ? AS val", "params" => ["42"]}

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [
          %{
            "success" => true,
            "results" => [%{"val" => "42"}],
            "meta" => %{
              "duration" => 0.01,
              "rows_read" => 1,
              "rows_written" => 0,
              "changes" => 0,
              "last_row_id" => 0,
              "size_after" => 8192
            }
          }
        ]
      })
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        database_id: "test-db-id",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.D1.Result{rows: [%{"val" => "42"}]}} =
             Cloudflareq.D1.query(req, "SELECT ? AS val", ["42"])
  end

  test "returns structured errors on API failure" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{
        "success" => false,
        "errors" => [%{"code" => 7500, "message" => "query error: syntax error"}],
        "messages" => [],
        "result" => []
      })
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        database_id: "test-db-id",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:error,
            %Cloudflareq.Error{
              errors: [%Cloudflareq.ErrorData{code: 7500, message: "query error: syntax error"}]
            }} =
             Cloudflareq.D1.query(req, "INVALID SQL")
  end

  test "query! raises on error" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{
        "success" => false,
        "errors" => [%{"code" => 7500, "message" => "bad query"}],
        "messages" => [],
        "result" => []
      })
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        database_id: "test-db-id",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert_raise Cloudflareq.Error, fn ->
      Cloudflareq.D1.query!(req, "INVALID SQL")
    end
  end

  test "batch executes multiple queries and returns results" do
    Req.Test.stub(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)

      assert %{
               "batch" => [
                 %{"sql" => "INSERT INTO t (v) VALUES (?)"},
                 %{"sql" => "SELECT * FROM t"}
               ]
             } = decoded

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [
          %{
            "success" => true,
            "results" => [],
            "meta" => %{
              "duration" => 0.01,
              "rows_read" => 0,
              "rows_written" => 1,
              "changes" => 1,
              "last_row_id" => 1,
              "size_after" => 8192
            }
          },
          %{
            "success" => true,
            "results" => [%{"v" => "hello"}],
            "meta" => %{
              "duration" => 0.02,
              "rows_read" => 1,
              "rows_written" => 0,
              "changes" => 0,
              "last_row_id" => 0,
              "size_after" => 8192
            }
          }
        ]
      })
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        database_id: "test-db-id",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, [%Cloudflareq.D1.Result{} = r1, %Cloudflareq.D1.Result{} = r2]} =
             Cloudflareq.D1.batch(req, [
               {"INSERT INTO t (v) VALUES (?)", ["hello"]},
               "SELECT * FROM t"
             ])

    assert r1.meta.changes == 1
    assert r2.rows == [%{"v" => "hello"}]
  end

  test "raw format hits /raw endpoint and returns columns+rows" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path =~ "/raw"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [
          %{
            "success" => true,
            "results" => %{
              "columns" => ["id", "name"],
              "rows" => [[1, "Alice"], [2, "Bob"]]
            },
            "meta" => %{
              "duration" => 0.01,
              "rows_read" => 2,
              "rows_written" => 0,
              "changes" => 0,
              "last_row_id" => 0,
              "size_after" => 8192
            }
          }
        ]
      })
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        database_id: "test-db-id",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.D1.Result{} = result} =
             Cloudflareq.D1.query(req, "SELECT * FROM users", [], d1_result_format: :raw)

    assert result.rows == %{"columns" => ["id", "name"], "rows" => [[1, "Alice"], [2, "Bob"]]}
  end

  test "list_databases returns a list of databases" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path =~ ~r|/d1/database$|

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [
          %{
            "uuid" => "db-1",
            "name" => "my-db",
            "version" => "production",
            "created_at" => "2024-01-01T00:00:00Z",
            "jurisdiction" => "eu"
          },
          %{
            "uuid" => "db-2",
            "name" => "other-db",
            "version" => "production",
            "created_at" => "2024-02-01T00:00:00Z",
            "jurisdiction" => nil
          }
        ]
      })
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, [%Cloudflareq.Database{} = db1, %Cloudflareq.Database{} = db2]} =
             Cloudflareq.D1.list_databases(req)

    assert db1.uuid == "db-1"
    assert db1.name == "my-db"
    assert db1.created_at == ~U[2024-01-01 00:00:00Z]
    assert db1.jurisdiction == "eu"
    assert db2.uuid == "db-2"
  end

  test "create_database creates a new database" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"name" => "my-new-db"} = Jason.decode!(body)

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "uuid" => "new-db-id",
          "name" => "my-new-db",
          "version" => "production",
          "created_at" => "2024-03-01T00:00:00Z",
          "jurisdiction" => nil
        }
      })
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.Database{} = db} = Cloudflareq.D1.create_database(req, "my-new-db")
    assert db.uuid == "new-db-id"
    assert db.name == "my-new-db"
    assert db.version == "production"
  end

  test "get_database returns database details" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path =~ "/d1/database/some-db-id"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "uuid" => "some-db-id",
          "name" => "my-db",
          "version" => "production",
          "created_at" => "2024-01-01T00:00:00Z",
          "jurisdiction" => "fedramp"
        }
      })
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.Database{} = db} = Cloudflareq.D1.get_database(req, "some-db-id")
    assert db.uuid == "some-db-id"
    assert db.name == "my-db"
    assert db.jurisdiction == "fedramp"
  end

  test "delete_database deletes a database" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path =~ "/d1/database/doomed-db"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert :ok = Cloudflareq.D1.delete_database(req, "doomed-db")
  end

  test "attach/2 composes with an existing Req.Request" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [
          %{
            "success" => true,
            "results" => [%{"1" => 1}],
            "meta" => %{
              "duration" => 0.01,
              "rows_read" => 1,
              "rows_written" => 0,
              "changes" => 0,
              "last_row_id" => 0,
              "size_after" => 8192
            }
          }
        ]
      })
    end)

    req =
      Req.new(
        plug: {Req.Test, __MODULE__},
        retry: false
      )
      |> Cloudflareq.D1.attach(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        database_id: "test-db-id"
      )

    assert {:ok, %Cloudflareq.D1.Result{rows: [%{"1" => 1}]}} =
             Cloudflareq.D1.query(req, "SELECT 1")
  end

  test "sets bearer token auth header" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [
          %{
            "success" => true,
            "results" => [],
            "meta" => %{
              "duration" => 0.0,
              "rows_read" => 0,
              "rows_written" => 0,
              "changes" => 0,
              "last_row_id" => 0,
              "size_after" => 0
            }
          }
        ]
      })
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        database_id: "test-db-id",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    Cloudflareq.D1.query(req, "SELECT 1")
  end

  test "stream_databases streams across multiple pages" do
    Req.Test.stub(__MODULE__, fn conn ->
      params = Plug.Conn.fetch_query_params(conn).query_params

      {databases, result_info} =
        case params["page"] do
          "1" ->
            {[
               %{
                 "uuid" => "db-1",
                 "name" => "first",
                 "version" => "production",
                 "num_tables" => 1,
                 "file_size" => 1024,
                 "created_at" => "2024-01-01T00:00:00Z"
               }
             ], %{"page" => 1, "per_page" => 1, "total_count" => 2, "count" => 1}}

          "2" ->
            {[
               %{
                 "uuid" => "db-2",
                 "name" => "second",
                 "version" => "production",
                 "num_tables" => 2,
                 "file_size" => 2048,
                 "created_at" => "2024-02-01T00:00:00Z"
               }
             ], %{"page" => 2, "per_page" => 1, "total_count" => 2, "count" => 1}}
        end

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => databases,
        "result_info" => result_info
      })
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    databases = Cloudflareq.D1.stream_databases(req, per_page: 1) |> Enum.to_list()

    assert [%Cloudflareq.Database{name: "first"}, %Cloudflareq.Database{name: "second"}] =
             databases
  end

  test "stream_databases with single page" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => [
          %{
            "uuid" => "db-1",
            "name" => "only",
            "version" => "production",
            "num_tables" => 1,
            "file_size" => 1024,
            "created_at" => "2024-01-01T00:00:00Z"
          }
        ],
        "result_info" => %{"page" => 1, "per_page" => 20, "total_count" => 1, "count" => 1}
      })
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert [%Cloudflareq.Database{name: "only"}] =
             Cloudflareq.D1.stream_databases(req) |> Enum.to_list()
  end

  test "stream_databases halts on error" do
    Req.Test.stub(__MODULE__, fn conn ->
      params = Plug.Conn.fetch_query_params(conn).query_params

      case params["page"] do
        "1" ->
          Req.Test.json(conn, %{
            "success" => true,
            "errors" => [],
            "messages" => [],
            "result" => [
              %{
                "uuid" => "db-1",
                "name" => "first",
                "version" => "production",
                "num_tables" => 1,
                "file_size" => 1024,
                "created_at" => "2024-01-01T00:00:00Z"
              }
            ],
            "result_info" => %{"page" => 1, "per_page" => 1, "total_count" => 2, "count" => 1}
          })

        "2" ->
          conn
          |> Plug.Conn.put_status(400)
          |> Req.Test.json(%{
            "success" => false,
            "errors" => [%{"code" => 7400, "message" => "unauthorized"}],
            "messages" => [],
            "result" => nil
          })
      end
    end)

    req =
      Cloudflareq.D1.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    results = Cloudflareq.D1.stream_databases(req, per_page: 1) |> Enum.to_list()
    assert [%Cloudflareq.Database{name: "first"}, {:error, %Cloudflareq.Error{}}] = results
  end
end
