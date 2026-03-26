defmodule Cloudflareq.R2Test do
  use ExUnit.Case, async: true

  test "list_buckets returns buckets with cursor" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path =~ ~r|/r2/buckets$|

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "buckets" => [
            %{
              "name" => "my-bucket",
              "creation_date" => "2024-01-01T00:00:00Z",
              "location" => "WNAM",
              "storage_class" => "Standard"
            },
            %{
              "name" => "other-bucket",
              "creation_date" => "2024-02-01T00:00:00Z",
              "location" => "ENAM",
              "storage_class" => "Standard"
            }
          ]
        },
        "result_info" => %{
          "cursor" => "next-page-token",
          "cursors" => %{"after" => "next-page-token"}
        }
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %{buckets: buckets, cursor: cursor}} = Cloudflareq.R2.list_buckets(req)
    assert length(buckets) == 2
    assert [%Cloudflareq.R2.Bucket{} = b1, %Cloudflareq.R2.Bucket{} = b2] = buckets
    assert b1.name == "my-bucket"
    assert b1.location == "WNAM"
    assert b2.name == "other-bucket"
    assert cursor == "next-page-token"
  end

  test "create_bucket creates a new bucket" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path =~ ~r|/r2/buckets$|
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"name" => "my-new-bucket"} = Jason.decode!(body)

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "name" => "my-new-bucket",
          "creation_date" => "2024-03-01T00:00:00Z",
          "location" => "WNAM",
          "storage_class" => "Standard"
        }
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.R2.Bucket{} = bucket} =
             Cloudflareq.R2.create_bucket(req, "my-new-bucket")

    assert bucket.name == "my-new-bucket"
    assert bucket.creation_date == ~U[2024-03-01 00:00:00Z]
    assert bucket.location == "WNAM"
  end

  test "create_bucket with location_hint and storage_class" do
    Req.Test.stub(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["name"] == "eu-bucket"
      assert decoded["locationHint"] == "eu"
      assert decoded["storageClass"] == "InfrequentAccess"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "name" => "eu-bucket",
          "creation_date" => "2024-03-01T00:00:00Z",
          "location" => "WEUR",
          "storage_class" => "InfrequentAccess"
        }
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.R2.Bucket{} = bucket} =
             Cloudflareq.R2.create_bucket(req, "eu-bucket",
               location_hint: "eu",
               storage_class: "InfrequentAccess"
             )

    assert bucket.storage_class == "InfrequentAccess"
  end

  test "get_bucket returns bucket details" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path =~ "/r2/buckets/my-bucket"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "name" => "my-bucket",
          "creation_date" => "2024-01-01T00:00:00Z",
          "location" => "WNAM",
          "storage_class" => "Standard"
        }
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.R2.Bucket{} = bucket} = Cloudflareq.R2.get_bucket(req, "my-bucket")
    assert bucket.name == "my-bucket"
  end

  test "delete_bucket deletes a bucket" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path =~ "/r2/buckets/doomed-bucket"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert :ok = Cloudflareq.R2.delete_bucket(req, "doomed-bucket")
  end

  test "create_temp_credentials returns credentials" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path =~ "/r2/temp-access-credentials"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["bucket"] == "my-bucket"
      assert decoded["parentAccessKeyId"] == "parent-key"
      assert decoded["permission"] == "object-read-write"
      assert decoded["ttlSeconds"] == 900

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "accessKeyId" => "temp-key-id",
          "secretAccessKey" => "temp-secret",
          "sessionToken" => "temp-session-token"
        }
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %Cloudflareq.R2.TempCredentials{} = creds} =
             Cloudflareq.R2.create_temp_credentials(req,
               bucket: "my-bucket",
               parent_access_key_id: "parent-key",
               permission: "object-read-write",
               ttl_seconds: 900
             )

    assert creds.access_key_id == "temp-key-id"
    assert creds.secret_access_key == "temp-secret"
    assert creds.session_token == "temp-session-token"
  end

  test "returns structured errors on API failure" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{
        "success" => false,
        "errors" => [%{"code" => 10006, "message" => "bucket not found"}],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:error,
            %Cloudflareq.Error{
              errors: [%Cloudflareq.ErrorData{code: 10006, message: "bucket not found"}]
            }} =
             Cloudflareq.R2.get_bucket(req, "nonexistent")
  end

  test "sets bearer token auth header" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{"buckets" => []},
        "result_info" => nil
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    Cloudflareq.R2.list_buckets(req)
  end

  test "sets jurisdiction header when configured" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert Plug.Conn.get_req_header(conn, "cf-r2-jurisdiction") == ["eu"]

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{"buckets" => []},
        "result_info" => nil
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        r2_jurisdiction: "eu",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    Cloudflareq.R2.list_buckets(req)
  end

  test "attach/2 composes with an existing Req.Request" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "buckets" => [
            %{
              "name" => "attached-bucket",
              "creation_date" => "2024-01-01T00:00:00Z",
              "location" => nil,
              "storage_class" => "Standard"
            }
          ]
        },
        "result_info" => nil
      })
    end)

    req =
      Req.new(
        plug: {Req.Test, __MODULE__},
        retry: false
      )
      |> Cloudflareq.R2.attach(cf_account_id: "test-account", cf_api_token: "test-token")

    assert {:ok, %{buckets: [%Cloudflareq.R2.Bucket{name: "attached-bucket"}]}} =
             Cloudflareq.R2.list_buckets(req)
  end

  test "get_lifecycle returns lifecycle rules" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path =~ "/r2/buckets/my-bucket/lifecycle"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "rules" => [
            %{
              "id" => "rule-1",
              "conditions" => %{"prefix" => "logs/"},
              "actions" => %{"type" => "Delete", "afterDays" => 30}
            }
          ]
        }
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %{"rules" => [rule]}} = Cloudflareq.R2.get_lifecycle(req, "my-bucket")
    assert rule["id"] == "rule-1"
  end

  test "put_lifecycle sets lifecycle rules" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path =~ "/r2/buckets/my-bucket/lifecycle"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert [%{"id" => "rule-1"}] = decoded["rules"]

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{}
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    rules = [
      %{
        "id" => "rule-1",
        "conditions" => %{"prefix" => "logs/"},
        "actions" => %{"type" => "Delete", "afterDays" => 30}
      }
    ]

    assert {:ok, _} = Cloudflareq.R2.put_lifecycle(req, "my-bucket", rules)
  end

  test "get_cors returns CORS rules" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path =~ "/r2/buckets/my-bucket/cors"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "rules" => [
            %{"allowedOrigins" => ["*"], "allowedMethods" => ["GET"]}
          ]
        }
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %{"rules" => [rule]}} = Cloudflareq.R2.get_cors(req, "my-bucket")
    assert rule["allowedOrigins"] == ["*"]
  end

  test "put_cors sets CORS rules" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path =~ "/r2/buckets/my-bucket/cors"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert [%{"allowedOrigins" => ["*"]}] = decoded["rules"]

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{}
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    rules = [%{"allowedOrigins" => ["*"], "allowedMethods" => ["GET", "PUT"]}]
    assert {:ok, _} = Cloudflareq.R2.put_cors(req, "my-bucket", rules)
  end

  test "delete_cors removes CORS configuration" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path =~ "/r2/buckets/my-bucket/cors"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert :ok = Cloudflareq.R2.delete_cors(req, "my-bucket")
  end

  test "s3/2 creates a Req.Request with ReqS3 attached" do
    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token"
      )

    s3 = Cloudflareq.R2.s3(req, access_key_id: "my-key", secret_access_key: "my-secret")
    assert %Req.Request{} = s3
    assert s3.options[:aws_endpoint_url_s3] == "https://test-account.r2.cloudflarestorage.com"
    assert s3.options[:aws_sigv4][:access_key_id] == "my-key"
    assert s3.options[:aws_sigv4][:secret_access_key] == "my-secret"
    assert s3.options[:aws_sigv4][:service] == :s3
  end

  test "s3/2 accepts TempCredentials struct" do
    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token"
      )

    creds = %Cloudflareq.R2.TempCredentials{
      access_key_id: "temp-key",
      secret_access_key: "temp-secret",
      session_token: "temp-token"
    }

    s3 = Cloudflareq.R2.s3(req, creds)
    assert %Req.Request{} = s3
    assert s3.options[:aws_sigv4][:access_key_id] == "temp-key"
    assert s3.options[:aws_sigv4][:secret_access_key] == "temp-secret"
    assert s3.options[:aws_sigv4][:token] == "temp-token"
  end

  test "presign_url/4 generates presigned URL with R2 endpoint" do
    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token"
      )

    url =
      Cloudflareq.R2.presign_url(req, "my-bucket", "hello.txt",
        access_key_id: "my-key",
        secret_access_key: "my-secret"
      )

    assert url =~ "test-account.r2.cloudflarestorage.com"
    assert url =~ "my-bucket"
    assert url =~ "hello.txt"
    assert url =~ "X-Amz-Algorithm"
  end

  test "presign_url/4 reads credentials from s3-configured request" do
    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token"
      )

    s3 = Cloudflareq.R2.s3(req, access_key_id: "s3-key", secret_access_key: "s3-secret")

    url = Cloudflareq.R2.presign_url(s3, "my-bucket", "photo.jpg")

    assert url =~ "test-account.r2.cloudflarestorage.com"
    assert url =~ "my-bucket"
    assert url =~ "photo.jpg"
    assert url =~ "X-Amz-Algorithm"
    assert url =~ "s3-key"
  end

  test "presign_url/4 explicit opts override s3 request credentials" do
    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token"
      )

    s3 = Cloudflareq.R2.s3(req, access_key_id: "s3-key", secret_access_key: "s3-secret")

    url =
      Cloudflareq.R2.presign_url(s3, "my-bucket", "photo.jpg",
        access_key_id: "override-key",
        secret_access_key: "override-secret"
      )

    assert url =~ "override-key"
    refute url =~ "s3-key"
  end

  test "presign_form/4 generates presigned form with R2 endpoint" do
    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token"
      )

    form =
      Cloudflareq.R2.presign_form(req, "my-bucket", "uploads/photo.jpg",
        access_key_id: "my-key",
        secret_access_key: "my-secret"
      )

    assert %{url: url, fields: fields} = form
    assert url =~ "test-account.r2.cloudflarestorage.com"
    assert url =~ "my-bucket"
    assert is_list(fields)
  end

  test "presign_form/4 reads credentials from s3-configured request" do
    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token"
      )

    s3 = Cloudflareq.R2.s3(req, access_key_id: "s3-key", secret_access_key: "s3-secret")

    form = Cloudflareq.R2.presign_form(s3, "my-bucket", "uploads/photo.jpg")

    assert %{url: url, fields: fields} = form
    assert url =~ "test-account.r2.cloudflarestorage.com"
    assert url =~ "my-bucket"
    assert is_list(fields)
    assert Enum.any?(fields, fn {k, _v} -> k == "x-amz-credential" end)
  end

  test "presign_form/4 explicit opts override s3 request credentials" do
    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token"
      )

    s3 = Cloudflareq.R2.s3(req, access_key_id: "s3-key", secret_access_key: "s3-secret")

    form =
      Cloudflareq.R2.presign_form(s3, "my-bucket", "uploads/photo.jpg",
        access_key_id: "override-key",
        secret_access_key: "override-secret"
      )

    assert %{fields: fields} = form
    credential_field = Enum.find(fields, fn {k, _} -> k == "x-amz-credential" end)
    assert {_, credential_value} = credential_field
    assert credential_value =~ "override-key"
    refute credential_value =~ "s3-key"
  end

  test "stream_buckets streams all items across multiple pages" do
    Req.Test.stub(__MODULE__, fn conn ->
      params = Plug.Conn.fetch_query_params(conn).query_params

      {buckets, cursor} =
        case params["cursor"] do
          nil ->
            {[
               %{
                 "name" => "a",
                 "creation_date" => "2024-01-01T00:00:00Z",
                 "location" => "WNAM",
                 "storage_class" => "Standard"
               }
             ], "page2"}

          "page2" ->
            {[
               %{
                 "name" => "b",
                 "creation_date" => "2024-02-01T00:00:00Z",
                 "location" => "ENAM",
                 "storage_class" => "Standard"
               }
             ], nil}
        end

      result_info = if cursor, do: %{"cursor" => cursor}, else: nil

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{"buckets" => buckets},
        "result_info" => result_info
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    buckets = Cloudflareq.R2.stream_buckets(req) |> Enum.to_list()
    assert [%Cloudflareq.R2.Bucket{name: "a"}, %Cloudflareq.R2.Bucket{name: "b"}] = buckets
  end

  test "stream_buckets with single page" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "buckets" => [
            %{
              "name" => "only",
              "creation_date" => "2024-01-01T00:00:00Z",
              "location" => "WNAM",
              "storage_class" => "Standard"
            }
          ]
        },
        "result_info" => nil
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert [%Cloudflareq.R2.Bucket{name: "only"}] =
             Cloudflareq.R2.stream_buckets(req) |> Enum.to_list()
  end

  test "stream_buckets halts on error" do
    Req.Test.stub(__MODULE__, fn conn ->
      params = Plug.Conn.fetch_query_params(conn).query_params

      case params["cursor"] do
        nil ->
          Req.Test.json(conn, %{
            "success" => true,
            "errors" => [],
            "messages" => [],
            "result" => %{
              "buckets" => [
                %{
                  "name" => "a",
                  "creation_date" => "2024-01-01T00:00:00Z",
                  "location" => "WNAM",
                  "storage_class" => "Standard"
                }
              ]
            },
            "result_info" => %{"cursor" => "page2"}
          })

        "page2" ->
          conn
          |> Plug.Conn.put_status(400)
          |> Req.Test.json(%{
            "success" => false,
            "errors" => [%{"code" => 10000, "message" => "something broke"}],
            "messages" => [],
            "result" => nil
          })
      end
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    results = Cloudflareq.R2.stream_buckets(req) |> Enum.to_list()
    assert [%Cloudflareq.R2.Bucket{name: "a"}, {:error, %Cloudflareq.Error{}}] = results
  end

  test "list_event_notification_rules returns configuration" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path =~ "/event_notifications/r2/my-bucket/configuration"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "queues" => %{
            "queue-1" => [
              %{"actions" => ["PutObject"], "prefix" => "images/", "suffix" => ".png"}
            ]
          }
        }
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:ok, %{"queues" => queues}} =
             Cloudflareq.R2.list_event_notification_rules(req, "my-bucket")

    assert [rule] = queues["queue-1"]
    assert rule["actions"] == ["PutObject"]
    assert rule["prefix"] == "images/"
  end

  test "list_event_notification_rules returns error on failure" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{
        "success" => false,
        "errors" => [%{"code" => 10006, "message" => "bucket not found"}],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:error,
            %Cloudflareq.Error{
              errors: [%Cloudflareq.ErrorData{code: 10006, message: "bucket not found"}]
            }} =
             Cloudflareq.R2.list_event_notification_rules(req, "nonexistent")
  end

  test "put_event_notification_rule creates a rule" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path =~ "/event_notifications/r2/my-bucket/configuration/queues/queue-1"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert [%{"actions" => ["PutObject"], "prefix" => "images/"}] = decoded["rules"]

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{}
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    rules = [%{"actions" => ["PutObject"], "prefix" => "images/"}]

    assert {:ok, _} =
             Cloudflareq.R2.put_event_notification_rule(req, "my-bucket", "queue-1", rules)
  end

  test "put_event_notification_rule returns error on failure" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{
        "success" => false,
        "errors" => [%{"code" => 10000, "message" => "invalid rule"}],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:error,
            %Cloudflareq.Error{
              errors: [%Cloudflareq.ErrorData{code: 10000, message: "invalid rule"}]
            }} =
             Cloudflareq.R2.put_event_notification_rule(req, "my-bucket", "queue-1", [
               %{"actions" => ["BadAction"]}
             ])
  end

  test "delete_event_notification_rule deletes a rule" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path =~ "/event_notifications/r2/my-bucket/configuration/queues/queue-1"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert :ok = Cloudflareq.R2.delete_event_notification_rule(req, "my-bucket", "queue-1")
  end

  test "delete_event_notification_rule returns error on failure" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{
        "success" => false,
        "errors" => [%{"code" => 10006, "message" => "queue not found"}],
        "messages" => [],
        "result" => nil
      })
    end)

    req =
      Cloudflareq.R2.new(
        cf_account_id: "test-account",
        cf_api_token: "test-token",
        plug: {Req.Test, __MODULE__},
        retry: false
      )

    assert {:error,
            %Cloudflareq.Error{
              errors: [%Cloudflareq.ErrorData{code: 10006, message: "queue not found"}]
            }} =
             Cloudflareq.R2.delete_event_notification_rule(req, "my-bucket", "nonexistent")
  end
end
