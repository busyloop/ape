require "bech32"
require "crystal-argon2"
require "digest/sha256"
require "uuid"

module Ape
  PASSPHRASE_MIN_LEN = 20
  ARGON2_COST_T = 19
  ARGON2_COST_M = 21
  ARGON2_SALT = "APE VERSION 1"

  # Derives age secret key from a passphrase.
  def self.secret_key(passphrase) : String
    Bech32.encode("AGE-SECRET-KEY-",
      Bech32.to_words(
        Digest::SHA256.digest(
          Argon2::Engine.hash_argon2id_encode(passphrase,
                                              ARGON2_SALT,
                                              t_cost: ARGON2_COST_T,
                                              m_cost: ARGON2_COST_M)
        )
      )
    )
  end

  # Returns age public key for age secret key.
  def self.public_key(secret_key) : String
    proc = Process.new("age-keygen", ["-y"], input: Process::Redirect::Pipe, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
    proc.input.write(secret_key.to_slice)
    proc.input.close
    proc.output.gets_to_end.chomp
  end

  # Spawns `age` to decrypt data from STDIN to STDOUT.
  def self.decrypt(secret_key)
    fifo = File.tempname(UUID.random.to_s)
    LibC.mkfifo fifo, 0o600
    proc = Process.new("age", ["-i", fifo, "--decrypt"], input: Process::Redirect::Pipe, output: STDOUT, error: STDERR)
    File.write(fifo, secret_key.to_slice)

    IO.copy STDIN, proc.input
    proc.input.close

    proc.wait.exit_code
  ensure
    File.delete?(fifo) if fifo
  end
end
