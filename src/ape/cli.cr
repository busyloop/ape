require "../ape"
require "./version"

class Ape::Error::Abort < Exception; end
class Ape::Error::AgeNotFound < Exception; end
class Ape::Error::AgeMalfunction < Exception; end

module Ape::Cli::Helpers
  def abort!(msg)
    STDERR.puts "ERROR: #{msg}"
    exit 1
  end

  def beep
    STDERR.print "\a"
  end

  def clear_line
    STDERR.print "\r\e[2K"
  end

  def age_must_be_in_path!
    %w[age age-keygen].each do |bin|
      raise Ape::Error::AgeMalfunction.new(bin) if Process.new(bin, ["--version"]).wait.exit_code != 0
    rescue File::NotFoundError
      raise Ape::Error::AgeNotFound.new(bin)
    end
  end

  def read_passphrase(prompt : String)
    chars = [] of Char
    STDERR.print prompt
    loop do
      fd = File.new("/dev/tty")
      char = fd.raw { fd.read_char }
      break if char.nil? || char.ord == 13
      raise Ape::Error::Abort.new("CTRL-C") if char.ord == 3
      if char.ord == 127
        if chars.size > 0
          chars.pop
        else
          beep
        end
        next
      end
      chars << char
    end
    clear_line

    abort! "Passphrase minimum length is #{Ape::PASSPHRASE_MIN_LEN} characters." if chars.size < Ape::PASSPHRASE_MIN_LEN
    chars.join
  end
end

module Ape::Cli
  include Ape::Cli::Helpers
  extend self

  PROMPT_PASSPHRASE = "Passphrase: "
  PROMPT_PASSPHRASE_REPEAT = "Repeat Passphrase: "

  ERR_PASSPHRASE_MISMATCH = "Mismatch."

  ANN_PLEASE_WAIT = "♨️  Deriving Key. Please wait."

  def lets_go!
    age_must_be_in_path!

    if %w[--version -V].includes? ARGV[0]?
      puts Ape::VERSION
      exit 0
    end

    exit STDIN.tty? ? derive! : decrypt!
  end

  def derive!
    passphrase = read_passphrase(PROMPT_PASSPHRASE)
    abort! ERR_PASSPHRASE_MISMATCH unless read_passphrase(PROMPT_PASSPHRASE_REPEAT) == passphrase

    STDERR.print ANN_PLEASE_WAIT

    secret_key = Ape.secret_key(passphrase)
    public_key = Ape.public_key(secret_key)

    clear_line

    STDERR.puts <<-EOPK

    Public key:

      \e[32;1m#{public_key}\e[0m
    EOPK

    STDERR.puts <<-EOM

    Run the following command to test encrypt and decrypt:

      \e[33mecho "OK" | age -r #{public_key} | #{PROGRAM_NAME}\e[0m


    EOM
    0
  end

  def decrypt!
    passphrase = read_passphrase(PROMPT_PASSPHRASE)

    STDERR.print ANN_PLEASE_WAIT
    secret_key = Ape.secret_key(passphrase)
    clear_line

    Ape.decrypt(secret_key)
  end
end

begin
  Ape::Cli.lets_go!
rescue ex : Ape::Error::Abort
  puts "*** Abort"
  exit 1
rescue ex : Ape::Error::AgeNotFound
  STDERR.puts <<-EOE

  Error!

  `#{ex.message}` must be in your $PATH.
  Please install age from https://github.com/FiloSottile/age


  EOE
  exit 1
rescue ex : Ape::Error::AgeMalfunction
  STDERR.puts <<-EOE

  Error!

  `#{ex.message} --version` exited with code != 0.

  Please install age from https://github.com/FiloSottile/age

  If this problem persists please file a bug at
  https://github.com/busyloop/ape/issues


  EOE
  exit 1
end
