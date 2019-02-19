if ENV['TRAVIS']
  require 'simplecov'
  require 'coveralls'

  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  SimpleCov.start do
    add_filter "spec/"
  end
end

require 'tempfile'
require 'miam'

Aws.config.update(
  access_key_id: ENV['MIAM_TEST_ACCESS_KEY_ID'] || 'scott',
  secret_access_key: ENV['MIAM_TEST_SECRET_ACCESS_KEY'] || 'tiger'
)

MIAM_TEST_ACCOUNT_ID = Aws::IAM::Client.new.get_user.user.user_id

RSpec.configure do |config|
  config.before(:each) do
    apply { '' }
  end

  config.after(:all) do
    apply { '' }
  end
end

def client(user_options = {})
  options = {
    logger: Logger.new('/dev/null'),
    no_progress: true
  }

  options[:password_manager] = Miam::PasswordManager.new('/dev/null', options)

  if_debug do
    logger = Miam::Logger.instance
    logger.set_debug(true)

    options.update(
      debug: true,
      logger: logger,
      aws_config: {
        http_wire_trace: true,
        logger: logger
      }
    )
  end

  options = options.merge(user_options)
  Miam::Client.new(options)
end

def tempfile(content, options = {})
  basename = "#{File.basename __FILE__}.#{$$}"
  basename = [basename, options[:ext]] if options[:ext]

  Tempfile.open(basename) do |f|
    f.puts(content)
    f.flush
    f.rewind
    yield(f)
  end
end

def apply(cli = client)
  result = tempfile(yield) do |f|
    begin
      cli.apply(f.path)
    rescue Aws::IAM::Errors::EntityTemporarilyUnmodifiable, Aws::IAM::Errors::Throttling, Aws::IAM::Errors::NoSuchEntity
      sleep 3
      retry
    end
  end

  sleep ENV['APPLY_WAIT'].to_i
  result
end

def export(options = {})
  options = {no_progress: true}.merge(options)
  cli = options.delete(:client) || Aws::IAM::Client.new
  Miam::Exporter.export(cli, options)[0]
end

def if_debug
  yield if ENV['DEBUG'] == '1'
end
