defmodule CloudflareqTest do
  use ExUnit.Case, async: true

  test "verify_token returns {:ok, %Token{}} on success" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "id" => "token-id-123",
          "status" => "active",
          "not_before" => "2024-01-01T00:00:00Z",
          "expires_on" => "2025-01-01T00:00:00Z"
        }
      })
    end)

    assert {:ok, token} =
             Cloudflareq.verify_token("test-token", plug: {Req.Test, __MODULE__})

    assert %Cloudflareq.Token{} = token
    assert token.id == "token-id-123"
    assert token.status == "active"
    assert token.not_before == "2024-01-01T00:00:00Z"
    assert token.expires_on == "2025-01-01T00:00:00Z"
  end

  test "verify_token returns {:error, %RuntimeError{}} on API failure" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(403)
      |> Req.Test.json(%{
        "success" => false,
        "errors" => [%{"code" => 1000, "message" => "Invalid API Token"}],
        "messages" => [],
        "result" => nil
      })
    end)

    assert {:error, %RuntimeError{message: message}} =
             Cloudflareq.verify_token("bad-token", plug: {Req.Test, __MODULE__})

    assert message =~ "Invalid API Token"
  end

  test "verify_token! raises on API error" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(403)
      |> Req.Test.json(%{
        "success" => false,
        "errors" => [%{"code" => 1000, "message" => "Invalid API Token"}],
        "messages" => [],
        "result" => nil
      })
    end)

    assert_raise RuntimeError, ~r/Invalid API Token/, fn ->
      Cloudflareq.verify_token!("bad-token", plug: {Req.Test, __MODULE__})
    end
  end

  test "verify_token returns {:error, %TokenError{}} when token is disabled" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "id" => "token-id-123",
          "status" => "disabled"
        }
      })
    end)

    assert {:error, %Cloudflareq.TokenError{status: "disabled"}} =
             Cloudflareq.verify_token("test-token", plug: {Req.Test, __MODULE__})
  end

  test "verify_token returns {:error, %TokenError{}} when token is expired" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "id" => "token-id-123",
          "status" => "expired"
        }
      })
    end)

    assert {:error, %Cloudflareq.TokenError{status: "expired"}} =
             Cloudflareq.verify_token("test-token", plug: {Req.Test, __MODULE__})
  end

  test "verify_token! raises TokenError when token is disabled" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "id" => "token-id-123",
          "status" => "disabled"
        }
      })
    end)

    assert_raise Cloudflareq.TokenError, "token is disabled", fn ->
      Cloudflareq.verify_token!("test-token", plug: {Req.Test, __MODULE__})
    end
  end

  test "verify_token sends GET to /user/tokens/verify" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/client/v4/user/tokens/verify"

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "id" => "token-id-123",
          "status" => "active"
        }
      })
    end)

    Cloudflareq.verify_token("test-token", plug: {Req.Test, __MODULE__})
  end

  test "verify_token sets bearer token auth header" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

      Req.Test.json(conn, %{
        "success" => true,
        "errors" => [],
        "messages" => [],
        "result" => %{
          "id" => "token-id-123",
          "status" => "active"
        }
      })
    end)

    Cloudflareq.verify_token("test-token", plug: {Req.Test, __MODULE__})
  end
end
