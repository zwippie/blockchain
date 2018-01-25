defmodule Blockchain.Instance do
  use GenServer

  # Client

  def start_link(node_id \\ nil, nodes \\ MapSet.new) do
    initial_state = %{
      blockchain: Blockchain.init,
      node_id: node_id || (Blockchain.Uuid.generate |> String.replace("-", "")),
      nodes: nodes
    }

    GenServer.start_link(__MODULE__, initial_state, name: :blockchain)
  end

  def node_id do
    GenServer.call(:blockchain, :node_id)
  end

  def nodes do
    GenServer.call(:blockchain, :nodes)
  end

  def blockchain do
    GenServer.call(:blockchain, :blockchain)
  end

  def new_transaction(sender, recipient, amount) do
    GenServer.call(:blockchain, {:new_transaction, sender, recipient, amount})
  end

  def mine do
    GenServer.call(:blockchain, :mine)
  end

  @doc """
  Add a new node to the list of nodes.

  Returns the new list of nodes.
  """
  def register_node(address) do
    GenServer.call(:blockchain, {:register_node, address})
  end

  @doc """
  This is our Consensus Algorithm, it resolves conflicts
  by replacing our chain with the longest one in the network.

  Returns true if our chain was replaced, false if not.
  """
  def resolve_conflicts do
    GenServer.call(:blockchain, :resolve_conflicts)
  end


  # Server (callbacks)

  def handle_call(:node_id, _from, %{node_id: node_id} = state) do
    {:reply, node_id, state}
  end

  def handle_call(:nodes, _from, %{nodes: nodes} = state) do
    {:reply, nodes |> MapSet.to_list, state}
  end

  def handle_call(:blockchain, _from, %{blockchain: blockchain} = state) do
    {:reply, blockchain, state}
  end

  def handle_call({:new_transaction, sender, recipient, amount}, _from, %{blockchain: blockchain} = state) do
    {blockchain, index} = Blockchain.new_transaction(blockchain, sender, recipient, amount)
    {:reply, index, %{state | blockchain: blockchain}}
  end

  def handle_call(:mine, _from, %{blockchain: blockchain} = state) do
    {blockchain, block} = Blockchain.mine(blockchain)
    {:reply, block, %{state | blockchain: blockchain}}
  end

  def handle_call({:register_node, address}, _from, %{nodes: nodes} = state) do
    nodes = MapSet.put(nodes, URI.parse(address).authority)
    {:reply, nodes, %{state | nodes: nodes}}
  end

  def handle_call(:resolve_conflicts, _from, %{nodes: nodes, blockchain: blockchain} = state) do
    # We're only looking for chains longer than ours
    # Grab and verify the chains from all the nodes in our network
    # Check if the length is longer and the chain is valid
    new_chain =
      nodes
      |> Stream.map(&fetch_remote_chain/1)
      |> Enum.reduce({length(blockchain.chain), blockchain.chain}, fn (remote_chain, {max_length, chain}) ->
        if length(remote_chain) > max_length && Blockchain.valid_chain?(remote_chain) do
          {length(remote_chain), remote_chain}
        else
          {max_length, chain}
        end
      end)
      |> elem(1)

    # Replace our chain if we discovered a new, valid chain longer than ours
    cond do
      new_chain != blockchain.chain ->
        blockchain = %{blockchain | chain: new_chain |> Enum.reverse}
        {:reply, true, %{state | blockchain: blockchain}}
      true ->
        {:reply, false, state}
    end
  end

  # TODO: Make error resilient, this crashes when remote node is down :/
  # Not a good idea to fetch urls from this genserver?
  defp fetch_remote_chain(node_name) do
    HTTPoison.get!("http://#{node_name}/chain").body
    |> Poison.decode!(as: %{"chain" => [%Blockchain.Block{}]})
    |> Map.get("chain")
  end

end
