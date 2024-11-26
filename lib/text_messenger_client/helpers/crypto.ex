defmodule TextMessengerClient.Helpers.Crypto do
  @moduledoc """
  Module for generating and managing RSA keys and symmetric encryption keys.
  """
  # RSA Keys
  @rsa_key_size 2048

  @block_size 16

  # Symmetric encryption key
  @group_key_length 32

  alias TextMessengerClient.Protobuf.{GroupKey, GroupKeys}

  @doc """
  Generates an RSA public-private key pair.

  ## Returns:
    - A tuple `{public_key, private_key}`:
      - `public_key`: An RSA public key in the format in binary format using DER encoding.
      - `private_key`: An RSA private key in the format in binary format using DER encoding`.

  ## Notes:
    - The public exponent is set to `65537`, a commonly used value for RSA.
    - The key size is determined by the module attribute `@rsa_key_size`.

  ## Example:
    {public_key, private_key} = generate_rsa_keys()
  """

  def generate_rsa_keys() do
    {:RSAPrivateKey, :"two-prime", modulus, public_exponent, private_exponent, prime1, prime2, exponent1, exponent2, coefficient, otherPrimeInfos} =
      :public_key.generate_key({:rsa, @rsa_key_size, 65537})

    private_key =
      {:RSAPrivateKey, :"two-prime", modulus, public_exponent, private_exponent, prime1, prime2, exponent1, exponent2, coefficient, otherPrimeInfos}
      |> encode_key(:RSAPrivateKey)

    public_key =
      {:RSAPublicKey, modulus, public_exponent}
      |> encode_key(:RSAPublicKey)

    {public_key, private_key}
  end


  @doc """
  Writes an RSA key (public or private) to a PEM-encoded file.

  ## Parameters:
    - `key`: The RSA key to be written. Must be in the format expected by the `:public_key` module.
    - `type`: The type of key, either `:RSAPublicKey` or `:RSAPrivateKey`.
    - `filepath`: The path to the file where the key will be written.

  ## Returns:
    - `:ok` if the key was successfully written.
    - `{:error, reason}` if an error occurred during file writing.

  ## Example:
      write_key_to_file(public_key, :RSAPublicKey, "public_key.pem")
  """
  def write_key_to_file(key, type, filepath) do
    decoded_key = decode_key(key, type)
    pem_entry = :public_key.pem_entry_encode(type, decoded_key)
    pem_data = :public_key.pem_encode([pem_entry])

    File.write(filepath, pem_data)
  end


  @doc """
  Reads an RSA key (public or private) from a PEM-encoded file.

  ## Parameters:
    - `type`: The type of key to read, either `:RSAPublicKey` or `:RSAPrivateKey`.
    - `filepath`: The path to the PEM file containing the key.

  ## Returns:
    - `binary()`: Key encoded in DER format if the file was successfully read and parsed.
    - `{:error, reason}` if an error occurred during reading or decoding.

  ## Notes:
    - The key must be in a format compatible with the `:public_key` module.
    - If the file contains multiple PEM entries, only the first one is decoded.

  ## Example:
      {:ok, private_key} = read_key_from_file(:RSAPrivateKey, "private_key.pem")
  """
  def read_key_from_file(type, filepath) do
    with {:ok, pem_data} <- File.read(filepath),
         [pem_entry] <- :public_key.pem_decode(pem_data),
         key <- :public_key.pem_entry_decode(pem_entry, type),
         encoded_key <- encode_key(key, type) do
      {:ok, encoded_key}
    else
      {:error, reason} -> {:error, reason}
      error -> error
    end
  end

  @doc """
  Generates a new group key, encrypts it for each chat member, and wraps it in a `GroupKeys` Protobuf struct.

  ## Parameters:
    - `members`: A list of tuples `{user_id, public_key}` representing chat members and their public keys.
    - `creator_id`: The ID of the user creating the group key.
    - `creator_private_key`: The private key of the creator used for signing the encrypted keys.

  ## Returns:
    - A `GroupKeys` Protobuf struct containing the encrypted and signed keys for each chat member.
  """
  def generate_group_keys(members, creator_id, creator_signature_key, chat_id) do
    decoded_creator_key = decode_key(creator_signature_key, :RSAPrivateKey)

    # Step 1: Generate a new random group key
    raw_key = generate_group_key()

    # Step 2: Encrypt and sign the group key for each chat member
    group_keys = Enum.map(members, fn {user_id, public_key} ->
      decoded_public_key = decode_key(public_key, :RSAPublicKey)
      raw_key
      |> encrypt_and_sign_group_key(decoded_creator_key, decoded_public_key)
      |> add_group_key_metadata(creator_id, user_id, chat_id)
    end)

    # Step 3: Wrap all keys into a GroupKeys Protobuf struct
    %GroupKeys{group_keys: group_keys}
  end

  @doc """
  Extracts and decrypts the group key from a `GroupKey` Protobuf struct.

  This function will:
  1. Extract the `encrypted_key` from the provided `GroupKey` struct.
  2. Use the provided `private_key` (recipient's private RSA key) to decrypt the `encrypted_key` using RSA decryption with `OAEP` padding.
  3. Return the decrypted group key, or an error if the decryption fails.

  ## Parameters
  - `group_key` (`%GroupKey{encrypted_key: binary()}`): The Protobuf struct containing the `encrypted_key` field, which is the encrypted group key.
  - `private_key` (`RSAPrivateKey`): The private RSA key of the recipient, used to decrypt the `encrypted_key`.

  ## Returns
  - `{:ok, binary()}`: If the decryption is successful, returns the decrypted group key as a binary.
  - `{:error, String.t()}`: If the decryption fails, returns an error tuple.

  ## Notes
  - The function uses RSA decryption with `:rsa_pkcs1_oaep_padding` padding scheme.
  - The `private_key` must be in the correct format (e.g., `:RSAPrivateKey`).
  """
  def extract_and_decrypt_group_key(%GroupKey{encrypted_key: encrypted_key}, private_key) do
    case :public_key.decrypt_private(encrypted_key, private_key, [{:rsa_padding, :rsa_pkcs1_oaep_padding}]) do
      {:ok, decrypted_key} ->
        {:ok, decrypted_key}

      {:error, _reason} ->
        {:error, "Decryption failed"}
    end
  end

  @doc """
  Verifies the signature of a `GroupKey` based on its `encrypted_key` field.

  ## Parameters:
    - `group_key`: A `GroupKey` struct containing the `encrypted_key` and `signature` fields.
    - `public_key`: The public key of the creator used to verify the signature.

  ## Returns:
    - `{:ok, encrypted_key}` if the signature is valid.
    - `{:error, reason}` if the signature verification fails.

  ## Notes:
    - This function authenticates the encrypted key to ensure it originated from the creator,
      but does not guarantee the integrity of the full protobuf struct.
  """
  def verify_group_key(%GroupKey{encrypted_key: encrypted_key, signature: signature}, public_key) do
    case :public_key.verify(encrypted_key, :sha256, signature, public_key, [{:rsa_padding, :rsa_pkcs1_pss_padding}]) do
      true -> {:ok, encrypted_key}
      false -> {:error, "Signature verification failed"}
    end
  end

  @doc """
  Encrypts a given plaintext message using AES-256-CBC with the provided symmetric key.

  ## Parameters
    - `message`: The plaintext message to encrypt.
    - `key`: The symmetric key used for encryption (binary, 32 bytes).

  ## Returns
    - `{cipher_text, iv}`: A tuple containing the encrypted message and the initialization vector (IV).
  """
  def encrypt_message(message, key) do
    if byte_size(key) != 32 do
      raise ArgumentError, "Key must be 32 bytes for AES-256 encryption"
    end

    iv = :crypto.strong_rand_bytes(16)
    padded_message = pkcs7_pad(message)
    cipher_text = :crypto.crypto_one_time(:aes_256_cbc, key, iv, padded_message, true)

    {cipher_text, iv}
  end

  @doc """
  Decrypts a given ciphertext using AES-256-CBC with the provided symmetric key and IV.

  ## Parameters
    - `cipher_text`: The encrypted message to decrypt (binary).
    - `iv`: The initialization vector used for decryption (binary, 16 bytes).
    - `key`: The symmetric key used for decryption (binary, 32 bytes).

  ## Returns
    - `message`: The decrypted plaintext message (binary).

  ## Raises
    - `ArgumentError` if the key or IV size is invalid.
  """
  def decrypt_message(cipher_text, iv, key) do
    if byte_size(key) != 32 do
      raise ArgumentError, "Key must be 32 bytes for AES-256 decryption"
    end

    if byte_size(iv) != 16 do
      raise ArgumentError, "IV must be 16 bytes for AES-256 decryption"
    end

    cipher_text
    |> :crypto.crypto_one_time(:aes_256_cbc, key, iv, false)
    |> pkcs7_unpad()
  end

  @doc """
  Encodes an RSA key into DER format.

  This function takes an RSA public or private key and encodes it into DER format, which is a binary encoding standard used for encoding cryptographic keys. The result is the DER-encoded binary data, suitable for further use or storage.

  ## Parameters
    - `key`: The RSA key to encode (must be an `:RSAPublicKey` or `:RSAPrivateKey` type).
    - `type`: The type of key to encode (`:RSAPublicKey` or `:RSAPrivateKey`).

  ## Returns
    - `binary()`: The DER-encoded binary representation of the key.

  ## Example

      iex> {public_key, _private_key} = generate_rsa_keys()
      iex> encode_key(public_key, :RSAPublicKey)
      <<48, 130, 2, 28, 48, 130, 1, 128, 2, 1, 0, 2, 204, 124, 182, ...>>
  """
  def encode_key(key, type) do
    :public_key.der_encode(type, key)
  end

  @doc """
  Decodes a DER-encoded RSA key.

  This function takes a DER-encoded binary key (in either public or private RSA key format) and decodes it back to the original RSA key structure. The function expects the input data to be in DER format, which is a binary encoding for cryptographic data.

  ## Parameters
    - `key`: The DER-encoded binary data representing the RSA key.
    - `type`: The type of key to decode (`:RSAPublicKey` or `:RSAPrivateKey`).

  ## Returns
    - `key`: The decoded RSA key in its original format.
    - `{:error, reason}`: An error tuple if decoding fails (e.g., invalid DER data).

  ## Example

      iex> {public_key, _private_key} = generate_rsa_keys()
      iex> encoded_key = encode_key(public_key, :RSAPublicKey)
      iex> decode_key(encoded_key, :RSAPublicKey)
      {:ok, %RSAPublicKey{modulus: ..., exponent: ...}}

      iex> decode_key(<<255, 255, 255>>, :RSAPublicKey)
      {:error, "Failed to decode key from DER data"}
  """
  def decode_key(key, type) do
    case :public_key.der_decode(type, key) do
      key -> key
      _ -> {:error, "Failed to decode key from DER data"}
    end
  end

  # Private functions

  # Group key generation helper functions

  defp generate_group_key(key_length \\ @group_key_length) do
    :crypto.strong_rand_bytes(key_length)
  end

  defp encrypt_and_sign_group_key(raw_key, signature_key, recipient_key) do
    encrypted_key = :public_key.encrypt_public(raw_key, recipient_key, [{:rsa_padding, :rsa_pkcs1_oaep_padding}])
    signature = :public_key.sign(encrypted_key, :sha256, signature_key, [{:rsa_padding, :rsa_pkcs1_pss_padding}])

    %GroupKey{
      encrypted_key: encrypted_key,
      signature: signature
    }
  end

  defp add_group_key_metadata(key, creator_id, recipient_id, chat_id) when is_struct(key, GroupKey) do
    %GroupKey{
      key
      | creator_id: creator_id,
        recipient_id: recipient_id,
        chat_id: chat_id
    }
  end

  # Padding helper functions

  defp pkcs7_pad(data) do
    padding_size = @block_size - rem(byte_size(data), @block_size)
    padding = :binary.copy(<<padding_size>>, padding_size)
    data <> padding
  end

  defp pkcs7_unpad(data) do
    <<padding_size>> = binary_part(data, byte_size(data) - 1, 1)
    :binary.part(data, 0, byte_size(data) - padding_size)
  end
end
