# Miam

Miam is a tool to manage IAM.

It defines the state of IAM using DSL, and updates IAM according to DSL.

[![Gem Version](https://badge.fury.io/rb/miam.svg)](http://badge.fury.io/rb/miam)
[![Build Status](https://travis-ci.org/winebarrel/miam.svg?branch=master)](https://travis-ci.org/winebarrel/miam)
[![Coverage Status](https://coveralls.io/repos/winebarrel/miam/badge.svg?branch=master&service=github)](https://coveralls.io/github/winebarrel/miam?branch=master)

**Notice**

* `>= 0.2.0`
  * Use [get_account_authorization_details](http://docs.aws.amazon.com/sdkforruby/api/Aws/IAM/Client.html#get_account_authorization_details-instance_method).
* `>= 0.2.1`
  * Support Managed Policy attach/detach
  * Support JSON format
* `>= 0.2.2`
  * Improve update (show diff)
  * Support Template
  * Add `--ignore-login-profile` option
  * Sort policy array
* `>= 0.2.3`
  * Support Custom Managed Policy
* `>= 0.2.4`
  * Fix for Password Policy ([RP#22](https://github.com/winebarrel/miam/pull/22))
  * Fix `--target` option for Policies ([RP#21](https://github.com/winebarrel/miam/pull/21))
  * Fix for `Rate exceeded` ([PR#23](https://github.com/winebarrel/miam/pull/23))

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'miam'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install miam

## Usage

```sh
export AWS_ACCESS_KEY_ID='...'
export AWS_SECRET_ACCESS_KEY='...'
export AWS_REGION='us-east-1'
miam -e -o IAMfile  # export IAM
vi IAMfile
miam -a --dry-run
miam -a             # apply `IAMfile`
```

## Help

```
Usage: miam [options]
    -p, --profile PROFILE_NAME
        --credentials-path PATH
    -k, --access-key ACCESS_KEY
    -s, --secret-key SECRET_KEY
    -r, --region REGION
    -a, --apply
    -f, --file FILE
        --dry-run
        --account-output FILE
    -e, --export
    -o, --output FILE
        --split
        --split-more
        --format=FORMAT
        --export-concurrency N
        --target REGEXP
        --ignore-login-profile
        --no-color
        --no-progress
        --debug
```

## IAMfile example

```ruby
require 'other/iamfile'

user "bob", :path => "/developer/" do
  login_profile :password_reset_required=>true

  groups(
    "Admin"
  )

  policy "bob-policy" do
    {"Version"=>"2012-10-17",
     "Statement"=>
      [{"Action"=>
         ["s3:Get*",
          "s3:List*"],
        "Effect"=>"Allow",
        "Resource"=>"*"}]}
  end

  attached_managed_policies(
    # attached_managed_policy
  )
end

user "mary", :path => "/staff/" do
  # login_profile :password_reset_required=>true

  groups(
    # no group
  )

  policy "s3-readonly" do
    {"Version"=>"2012-10-17",
     "Statement"=>
      [{"Action"=>
         ["s3:Get*",
          "s3:List*"],
        "Effect"=>"Allow",
        "Resource"=>"*"}]}
  end

  policy "route53-readonly" do
    {"Version"=>"2012-10-17",
     "Statement"=>
      [{"Action"=>
         ["route53:Get*",
          "route53:List*"],
        "Effect"=>"Allow",
        "Resource"=>"*"}]}
  end

  attached_managed_policies(
    "arn:aws:iam::aws:policy/AdministratorAccess",
    "arn:aws:iam::123456789012:policy/my_policy"
  )
end

group "Admin", :path => "/admin/" do
  policy "Admin" do
    {"Statement"=>[{"Effect"=>"Allow", "Action"=>"*", "Resource"=>"*"}]}
  end
end

role "S3", :path => "/" do
  instance_profiles(
    "S3"
  )

  assume_role_policy_document do
    {"Version"=>"2012-10-17",
     "Statement"=>
      [{"Sid"=>"",
        "Effect"=>"Allow",
        "Principal"=>{"Service"=>"ec2.amazonaws.com"},
        "Action"=>"sts:AssumeRole"}]}
  end

  policy "S3-role-policy" do
    {"Version"=>"2012-10-17",
     "Statement"=>[{"Effect"=>"Allow", "Action"=>"*", "Resource"=>"*"}]}
  end
end

instance_profile "S3", :path => "/"
```

## Rename

```ruby
require 'other/iamfile'

user "bob2", :path => "/developer/", :renamed_from => "bob" do
  # ...
end

group "Admin2", :path => "/admin/". :renamed_from => "Admin" do
  # ...
end
```

## Managed Policy attach/detach

```ruby
user "bob", :path => "/developer/" do
  login_profile :password_reset_required=>true

  groups(
    "Admin"
  )

  policy "bob-policy" do
    # ...
  end

  attached_managed_policies(
    "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"
  )
end
```

## Custom Managed Policy

```ruby
managed_policy "my-policy", :path=>"/" do
  {"Version"=>"2012-10-17",
   "Statement"=>
    [{"Effect"=>"Allow", "Action"=>"directconnect:Describe*", "Resource"=>"*"}]}
end

user "bob", :path => "/developer/" do
  login_profile :password_reset_required=>true

  groups(
    "Admin"
  )

  policy "bob-policy" do
    # ...
  end

  attached_managed_policies(
    "arn:aws:iam::123456789012:policy/my-policy"
  )
end
```

## Use JSON

```sh
$ miam -e -o iam.json
   ᗧ 100%
Export IAM to `iam.json`

$ cat iam.json
{
  "users": {
    "bob": {
      "path": "/",
      "groups": [
        "Admin"
      ],
      "policies": {
      ...

$ miam -a -f iam.json --dry-run
Apply `iam.json` to IAM (dry-run)
   ᗧ 100%
No change
```

## Use Template

```ruby
template "common-policy" do
  policy "my-policy" do
    {"Version"=>context.version,
     "Statement"=>
      [{"Action"=>
         ["s3:Get*",
          "s3:List*"],
        "Effect"=>"Allow",
        "Resource"=>"*"}]}
  end
end

template "common-role-attrs" do
  assume_role_policy_document do
    {"Version"=>context.version,
     "Statement"=>
      [{"Sid"=>"",
        "Effect"=>"Allow",
        "Principal"=>{"Service"=>"ec2.amazonaws.com"},
        "Action"=>"sts:AssumeRole"}]}
  end
end

user "bob", :path => "/developer/" do
  login_profile :password_reset_required=>true

  groups(
    "Admin"
  )

  include_template "common-policy", version: "2012-10-17"
end

user "mary", :path => "/staff/" do
  # login_profile :password_reset_required=>true

  groups(
    # no group
  )

  context.version = "2012-10-17"
  include_template "common-policy"

  attached_managed_policies(
    "arn:aws:iam::aws:policy/AdministratorAccess",
    "arn:aws:iam::123456789012:policy/my_policy"
  )
end

role "S3", :path => "/" do
  instance_profiles(
    "S3"
  )

  include_template "common-role-attrs"

  policy "S3-role-policy" do
    {"Version"=>"2012-10-17",
     "Statement"=>[{"Effect"=>"Allow", "Action"=>"*", "Resource"=>"*"}]}
  end
end
```

## Similar tools
* [Codenize.tools](http://codenize.tools/)
