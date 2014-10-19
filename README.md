# Miam

Miam is a tool to manage IAM.

It defines the state of IAM using DSL, and updates IAM according to DSL.

[![Gem Version](https://badge.fury.io/rb/miam.svg)](http://badge.fury.io/rb/miam)
[![Build Status](https://travis-ci.org/winebarrel/miam.svg?branch=master)](https://travis-ci.org/winebarrel/miam)
[![Coverage Status](https://coveralls.io/repos/winebarrel/miam/badge.png?branch=master)](https://coveralls.io/r/winebarrel/miam?branch=master)

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
end

group "Admin", :path => "/admin/" do
  policy "Admin" do
    {"Statement"=>[{"Effect"=>"Allow", "Action"=>"*", "Resource"=>"*"}]}
  end
end
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
