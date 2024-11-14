defmodule TextMessengerClient.Crypto do
  @moduledoc """
  Module for generating and managing RSA keys and symmetric encryption keys.
  """
  # RSA Keys
  @rsa_key_size 2048

  # Symmetric encryption key
  @group_key_length 32

  @block_size 16

  alias TextMessengerClient.Protobuf.GroupKey

  def generate_rsa_keys() do
    {:RSAPrivateKey, :"two-prime", modulus, public_exponent, private_exponent, prime1, prime2, exponent1, exponent2, coefficient, otherPrimeInfos} =
      :public_key.generate_key({:rsa, @rsa_key_size, 65537})

    private_key = {:RSAPrivateKey, :"two-prime", modulus, public_exponent, private_exponent, prime1, prime2, exponent1, exponent2, coefficient, otherPrimeInfos}

    public_key = {:RSAPublicKey, modulus, public_exponent}

    {public_key, private_key}
  end

  def write_key_to_file(key, type, filepath) do
    pem_entry = :public_key.pem_entry_encode(type, key)
    pem_data = :public_key.pem_encode([pem_entry])

    File.write(filepath, pem_data)
  end

  def read_key_from_file(type, filepath) do
    with {:ok, pem_data} <- File.read(filepath),
         [pem_entry] <- :public_key.pem_decode(pem_data),
         {:ok, key} <- :public_key.pem_entry_decode(pem_entry, type) do
      key
    else
      error -> error
    end
  end

  def generate_group_key(private_key, key_length \\ @group_key_length) do
    key = :crypto.strong_rand_bytes(key_length)
    group_key = %GroupKey{
      key: key
    }

    serialized_group_key = GroupKey.encode(group_key)

    signature = :public_key.sign(serialized_group_key, :sha256, private_key, [{:rsa_padding, :rsa_pkcs1_pss_padding}])

    %GroupKey{group_key | signature: signature}

  end

  def verify_group_key(group_key, public_key) do
    {key, signature} = {group_key.key, group_key.signature}

    serialized_group_key = GroupKey.encode(%GroupKey{group_key | signature: <<>>})

    case :public_key.verify(serialized_group_key, :sha256, signature, public_key, [{:rsa_padding, :rsa_pkcs1_pss_padding}]) do
      true -> {:ok, key}
      false -> {:error, "Signature verification failed"}
    end
  end

  def encrypt_message(message, group_key) do
    symmetric_key = group_key.key

    iv = :crypto.strong_rand_bytes(16)
    padded_message = pkcs7_pad(message)
    cipher_text = :crypto.crypto_one_time(:aes_256_cbc, symmetric_key, iv, padded_message, true)

    {cipher_text, iv}
  end

  def decrypt_message(cipher_text, iv, group_key) do
    symmetric_key = group_key.key

    :crypto.crypto_one_time(:aes_256_cbc, symmetric_key, iv, cipher_text, false)
    |> pkcs7_unpad()
  end

  defp pkcs7_pad(data) do
    padding_size = @block_size - rem(byte_size(data), @block_size)
    padding = <<padding_size::integer-size(8)>> |> :binary.copy(padding_size)
    data <> padding
  end

  defp pkcs7_unpad(data) do
    <<padding_size>> = binary_part(data, byte_size(data) - 1, 1)
    :binary.part(data, 0, byte_size(data) - padding_size)
  end

end
