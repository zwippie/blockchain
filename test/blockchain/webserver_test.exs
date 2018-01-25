defmodule Blockchain.WebServerTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @opts Blockchain.WebServer.init([])

  test "returns some sort of welcome" do
    # Create a test connection
    conn = conn(:get, "/")

    # Invoke the plug
    conn = Blockchain.WebServer.call(conn, @opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "Blockchain!"
  end

  test "returns a 404 on a non-existing route" do
    conn = conn(:get, "/foo") |> Blockchain.WebServer.call(@opts)
    assert conn.state == :sent
    assert conn.status == 404
    assert conn.resp_body == "Page not found"
  end

  test "GET /chain returns the current blockchain" do
    conn = conn(:get, "/chain") |> Blockchain.WebServer.call(@opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert {:ok, %{"chain" => chain}} = conn.resp_body |> Poison.decode
    assert is_list(chain)
  end

  test "GET /mine mines a new block" do
    conn = conn(:get, "/mine") |> Blockchain.WebServer.call(@opts)

    assert conn.state == :sent
    assert conn.status == 201
    assert {:ok, %{"message" => "New block forged", "block" => _block}} = conn.resp_body |> Poison.decode
  end

  test "POST /transactions adds a new transaction" do
    conn = post_json "/transactions", %{sender: "123", recipient: "666", amount: 10}

    assert conn.state == :sent
    assert conn.status == 201
  end

  test "POST /nodes/register registers new nodes" do
    conn = post_json "/nodes/register", %{nodes: ["http://localhost:5001"]}

    assert conn.state == :sent
    assert conn.status == 201
    assert {:ok, %{"message" => "New nodes have been added", "total_nodes" => 1}} = conn.resp_body |> Poison.decode
  end

  @tag :skip # fails sometimes if /nodes/register test has been ran before this one
  test "GET /nodes/resolve returns false when no other nodes are registered" do
    conn = conn(:get, "/nodes/resolve") |> Blockchain.WebServer.call(@opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert {:ok, %{"message" => "Our chain is authoritative", "chain" => _chain}} = conn.resp_body |> Poison.decode
  end

  @tag :skip
  test "start another app" do
    Application.put_env(:blockchain, :cowboy_port, 4003)
    {:ok, _pid} = Blockchain.Application.start([], [])

    assert {:ok, []} = Application.ensure_all_started(:blockchain)

    assert {:ok, _response} = HTTPoison.get("http://localhost:4003/chain")
  end

  defp post_json(path, body) do
    conn(:post, path, Poison.encode!(body))
    |> put_req_header("content-type", "application/json")
    |> Blockchain.WebServer.call(@opts)
  end
end
