class Miam::PasswordManager
  include Miam::Logger::Helper

  LOWERCASES = ('a'..'z').to_a
  UPPERCASES = ('A'..'Z').to_a
  NUMBERS = ('0'..'9').to_a
  SYMBOLS = "!@\#$%^&*()_+-=[]{}|'".split(//)

  def initialize(output, options = {})
    @output = output
    @options = options
  end

  def identify(user, type, policy)
    password = mkpasswd(policy)
    log(:info, "mkpasswd: #{password}")
    puts_password(user, type, password)
    password
  end

  def puts_password(user, type, password)
    log(:info, "User `#{user}` > `#{type}`: put password to `#{@output}`")

    open_output do |f|
      f.puts("#{user},#{type},#{password}")
    end
  end

  private

  def mkpasswd(policy)
    chars = []
    len = 8

    if policy
      len = policy.minimum_password_length if policy.minimum_password_length > len
      chars << LOWERCASES.shuffle.first if policy.require_lowercase_characters
      chars << UPPERCASES.shuffle.first if policy.require_uppercase_characters
      chars << NUMBERS.shuffle.first if policy.require_numbers
      chars << SYMBOLS.shuffle.first if policy.require_symbols

      len -= chars.length
    end

    (chars + [*1..9, *'A'..'Z', *'a'..'z'].shuffle.slice(0, len)).shuffle.join
  end

  def open_output
    return if @options[:dry_run]

    if @output == '-'
      yield($stdout)
      $stdout.flush
    else
      open(@output, 'a') do |f|
        yield(f)
      end
    end
  end
end
