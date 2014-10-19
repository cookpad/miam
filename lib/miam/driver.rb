class Miam::Driver
  include Miam::Logger::Helper

  MAX_POLICY_SIZE = 2048

  def initialize(iam, options = {})
    @iam = iam
    @options = options
  end

  # XXX:

  def put_policy(type, user_or_group_name, policy_name, policy_document)
    logmsg = <<-EOS.strip
Update #{Miam::Utils.camelize(type.to_s)} `#{user_or_group_name}` > Policy `#{policy_name}`
  #{policy_document.pretty_inspect.gsub("\n", "\n  ").strip}
EOS

    log(:info, logmsg, :color => :green)

    unless_dry_run do
      params = {
        :policy_name => policy_name,
        :policy_document => encode_document(policy_document),
      }

      params["#{type}_name".to_sym] = user_or_group_name
      @iam.send("put_#{type}_policy", params)
    end
  end

  private

  def encode_document(policy_document)
    encoded = JSON.pretty_generate(policy_document)

    if Miam::Utils.bytesize(encoded) > MAX_POLICY_SIZE
      encoded = JSON.pretty_generate(policy_document)
      encoded = encoded.gsub(/^\s+/m, '').strip
    end

    if Miam::Utils.bytesize(encoded) > MAX_POLICY_SIZE
      encoded = JSON.dump(policy_document)
    end

    encoded
  end

  def unless_dry_run
    yield unless @options[:dry_run]
  end
end
