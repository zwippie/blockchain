defmodule Blockchain do
  @moduledoc """
  Simple Blockchain as described in https://hackernoon.com/learn-blockchains-by-building-one-117428612f46.
  """

  @derive [Poison.Encoder]
  defstruct chain: [], current_transactions: []

  defmodule Block do
    @derive [Poison.Encoder]
    defstruct index: 0, timestamp: 0, transactions: [], proof: 0, previous_hash: ""
  end

  defmodule Transaction do
    @derive [Poison.Encoder]
    defstruct sender: "", recipient: "", amount: 0
  end

  @doc """
  Initialize a new blockchain, create and add the genesis block.
  """
  def init(previous_hash \\ "1", proof \\ 100) do
    {blockchain, _block} = new_block(%Blockchain{}, proof, previous_hash)
    blockchain
  end

  @doc """
  Create a new Block in the Blockchain
  """
  def new_block(%Blockchain{} = blockchain, proof, previous_hash \\ nil) do
    block = %Block{
      index: length(blockchain.chain) + 1,
      timestamp: DateTime.utc_now |> DateTime.to_unix(:microsecond),
      transactions: blockchain.current_transactions,
      proof: proof,
      previous_hash: previous_hash || (blockchain |> last_block |> hash)
    }

    # Reset the current list of transactions and add the new block to the chain
    blockchain = %{blockchain | current_transactions: [], chain: [block | blockchain.chain]}
    {blockchain, block}
  end

  @doc """
  Create a new transaction to go into the next mined Block
  """
  def new_transaction(%Blockchain{} = blockchain, sender, recipient, amount) do
    transaction = %Transaction{sender: sender, recipient: recipient, amount: amount}
    blockchain = %{blockchain | current_transactions: [transaction | blockchain.current_transactions]}
    {blockchain, last_block(blockchain).index + 1}
  end

  # Creates a SHA-256 hash of a Block
  # TODO: Guarantee ordering of block attributes when encoding to JSON
  defp hash(%Blockchain.Block{} = block) do
    :crypto.hash(:sha256, Poison.encode!(block))
    |> Base.encode16(case: :lower)
  end

  defp last_block(%Blockchain{chain: chain}) do
    hd(chain)
  end

  @doc """
  Simple Proof of Work Algorithm:
   - Find a number p' such that hash(pp') contains leading 4 zeroes, where p is the previous p'
   - p is the previous proof, and p' is the new proof
  """
  def proof_of_work(last_block) do
    last_proof = last_block.proof
    last_hash = hash(last_block)

    proof_of_work(last_proof, 0, last_hash)
  end

  def proof_of_work(last_proof, proof, last_hash) do
    cond do
      valid_proof?(last_proof, proof, last_hash) -> proof
      true -> proof_of_work(last_proof, proof + 1, last_hash)
    end
  end

  @doc """
  Validates the Proof: Does hash(last_proof, proof, last_hash) contain 4 leading zeroes?
  """
  def valid_proof?(last_proof, proof, last_hash) do
    guess = "#{last_proof}#{proof}#{last_hash}"
    guess_hash = :crypto.hash(:sha256, guess) |> Base.encode16(case: :lower)
    binary_part(guess_hash, 0, 4) == "0000"
  end

  @doc """
  Mine a new coin and give it to the recipient
  """
  def mine(%Blockchain{} = blockchain, recipient \\ "666") do
    # We run the proof of work algorithm to get the next proof...
    last_block = last_block(blockchain)
    proof = proof_of_work(last_block)

    # We must receive a reward for finding the proof.
    # The sender is "0" to signify that this node has mined a new coin.
    {blockchain, _index} = new_transaction(blockchain, "0", recipient, 1)

    # Forge the new Block by adding it to the chain
    previous_hash = hash(last_block)
    new_block(blockchain, proof, previous_hash)
  end

  @doc """
  Determine if a given blockchain is valid
  """
  def valid_chain?(%Blockchain{} = blockchain) do
    blockchain.chain |> Enum.reverse |> valid_chain?
  end

  def valid_chain?([last_block | chain]) do
    valid_chain?(chain, last_block)
  end

  defp valid_chain?([], _), do: true
  defp valid_chain?([block | tail], last_block) do
    cond do
      block.previous_hash != hash(last_block) -> false
      not valid_proof?(last_block.proof, block.proof, block.previous_hash) -> false
      true -> valid_chain?(tail, block)
    end
  end

  @doc """
  Determine the current saldo of a user, including current_transactions.
  """
  def saldo(%Blockchain{chain: chain, current_transactions: current_transactions}, user_id) do
    Enum.reduce(chain, 0, fn block, acc -> acc + mutations(block.transactions, user_id) end) +
    Enum.reduce(current_transactions, 0, fn block, acc -> acc + mutations(block.transactions, user_id) end)
  end

  defp mutations(transactions, user_id, acc \\ 0)
  defp mutations([], _user_id, acc), do: acc
  defp mutations([%{amount: amount, sender: sender_id} | tail], user_id, acc) when sender_id == user_id do
    mutations(tail, user_id, acc - amount)
  end
  defp mutations([%{amount: amount, recipient: recipient_id} | tail], user_id, acc) when recipient_id == user_id do
    mutations(tail, user_id, acc + amount)
  end
end
