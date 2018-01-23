defmodule BlockchainTest do
  use ExUnit.Case
  doctest Blockchain

  test "the blockchain stays valid when we mine and do transactions" do
    blockchain = Blockchain.init
    assert Blockchain.valid_chain?(blockchain)

    {blockchain, %Blockchain.Block{}} = Blockchain.mine(blockchain)
    assert Blockchain.valid_chain?(blockchain)

    {blockchain, %Blockchain.Block{}} = Blockchain.mine(blockchain)
    assert Blockchain.valid_chain?(blockchain)

    {blockchain, 4} = Blockchain.new_transaction(blockchain, "666", "13", 1)
    assert Blockchain.valid_chain?(blockchain)

    {blockchain, %Blockchain.Block{}} = Blockchain.mine(blockchain)
    assert Blockchain.valid_chain?(blockchain)

    {blockchain, 5} = Blockchain.new_transaction(blockchain, "13", "14", 1)
    {blockchain, %Blockchain.Block{}} = Blockchain.mine(blockchain)
    assert Blockchain.valid_chain?(blockchain)
  end
end
