class Miam::PasswordManager
  include Miam::Logger::Helper

  def initialize(output, options = {})
    @output = output
    @options = options
  end

  def identify(user, type)
    password = mkpasswd
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

  def mkpasswd(len = 8)
    [*1..9, *'A'..'Z', *'a'..'z'].shuffle.slice(0, len).join
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
