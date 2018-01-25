defmodule Blockchain.WebServer do
  use Plug.Router

  plug Plug.Parsers, parsers: [:json],
                     pass:  ["text/*"],
                     json_decoder: Poison
  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, "Blockchain!")
  end

  get "/mine" do
    block = Blockchain.Instance.mine

    send_json conn, 201, %{message: "New block forged", block: block}
  end

  post "/transactions" do
    %{"sender" => sender, "recipient" => recipient, "amount" => amount} = conn.body_params

    index = Blockchain.Instance.new_transaction(sender, recipient, amount)

    send_json conn, 201, %{message: "Transaction will be added to Block #{index}"}
  end

  get "/chain" do
    chain = Blockchain.Instance.blockchain.chain |> Enum.reverse

    send_json conn, 200, %{chain: chain}
  end

  post "/nodes/register" do
    %{"nodes" => nodes} = conn.body_params

    nodes |> Enum.each(&Blockchain.Instance.register_node/1)
    total_nodes = Blockchain.Instance.nodes |> length

    send_json conn, 201, %{message: "New nodes have been added", total_nodes: total_nodes}
  end

  get "/nodes/resolve" do
    is_replaced = Blockchain.Instance.resolve_conflicts
    chain = Blockchain.Instance.blockchain.chain |> Enum.reverse
    message = case is_replaced do
      true -> "Our chain was replaced"
      false -> "Our chain is authoritative"
    end

    send_json conn, 200, %{message: message, chain: chain}
  end

  match _ do
    send_resp(conn, 404, "Page not found")
  end

  defp send_json(conn, status_code, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status_code, data |> Poison.encode!)
  end
end
