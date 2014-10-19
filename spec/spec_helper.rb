require 'tempfile'
require 'miam'

Aws.config.update(
  access_key_id: ENV['MIAM_TEST_ACCESS_KEY_ID'],
  secret_access_key: ENV['MIAM_TEST_SECRET_ACCESS_KEY']
)

RSpec.configure do |config|
  config.before(:each) do
    apply { '' }
  end
end

def client(user_options = {})
  options = {logger: Logger.new('/dev/null')}

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
  tempfile(yield) do |f|
    cli.apply(f.path)
  end
end

def if_debug
  yield if ENV['DEBUG'] == '1'
end
