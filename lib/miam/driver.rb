class Miam::Driver
  include Miam::Logger::Helper

  MAX_POLICY_SIZE = 2048

  def initialize(iam, options = {})
    @iam = iam
    @options = options
  end

  def create_group(group_name, attrs)
    log(:info, "Create Group `#{group_name}`", :color => :cyan)

    unless_dry_run do
      params = {:group_name => group_name}
      params[:path] = attrs[:path] if attrs[:path]
      @iam.create_group(params)
    end
  end

  def delete_group(group_name)
    log(:info, "Delete Group `#{group_name}`", :color => :red)

    unless_dry_run do
      @iam.delete_group(:group_name => group_name)
    end
  end

  def update_name(type, user_or_group_name, new_name)
    log(:info, "Update #{Miam::Utils.camelize(type.to_s)} `#{user_or_group_name}`", :color => :green)
    log(:info, "  set name=#{new_name}", :color => :green)
    update_user_or_group(type, user_or_group_name, "new_#{type}_name".to_sym => new_name)
  end

  def update_path(type, user_or_group_name, new_path)
    log(:info, "Update #{Miam::Utils.camelize(type.to_s)} `#{user_or_group_name}`", :color => :green)
    log(:info, "  set path=#{new_path}", :color => :green)
    update_user_or_group(type, user_or_group_name, :new_path => new_path)
  end

  def update_user_or_group(type, user_or_group_name, params)
    unless_dry_run do
      params["#{type}_name".to_sym] = user_or_group_name
      @iam.send("update_#{type}", params)
    end
  end

  def create_policy(type, user_or_group_name, policy_name, policy_document)
    log(:info, "Create #{Miam::Utils.camelize(type.to_s)} `#{user_or_group_name}` > Policy `#{policy_name}`", :color => :cyan)
    log(:info, "  #{policy_document.pretty_inspect.gsub("\n", "\n  ").strip}", :color => :cyan)
    put_policy(type, user_or_group_name, policy_name, policy_document)
  end

  def update_policy(type, user_or_group_name, policy_name, policy_document)
    log(:info, "Update #{Miam::Utils.camelize(type.to_s)} `#{user_or_group_name}` > Policy `#{policy_name}`", :color => :green)
    log(:info, "  #{policy_document.pretty_inspect.gsub("\n", "\n  ").strip}", :color => :green)
    put_policy(type, user_or_group_name, policy_name, policy_document)
  end

  def delete_policy(type, user_or_group_name, policy_name)
    logmsg = "Delete #{Miam::Utils.camelize(type.to_s)} `#{user_or_group_name}` > Policy `#{policy_name}`"
    log(:info, logmsg, :color => :red)

    unless_dry_run do
      params = {:policy_name => policy_name}
      params["#{type}_name".to_sym] = user_or_group_name
      @iam.send("delete_#{type}_policy", params)
    end
  end

  def put_policy(type, user_or_group_name, policy_name, policy_document)
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
    if @options[:disable_form_json]
      JSON.dump(policy_document)
    else
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
  end

  def unless_dry_run
    yield unless @options[:dry_run]
  end
end
