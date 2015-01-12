---
layout: default
---

# Miam

[![Gem Version](https://badge.fury.io/rb/miam.svg)](http://badge.fury.io/rb/miam)
[![Build Status](https://travis-ci.org/winebarrel/miam.svg?branch=master)](https://travis-ci.org/winebarrel/miam)
[![Coverage Status](https://img.shields.io/coveralls/winebarrel/miam.svg)](https://coveralls.io/r/winebarrel/miam?branch=master)

**Notice**

* `>= 0.2.0`
  * Use [get_account_authorization_details](http://docs.aws.amazon.com/sdkforruby/api/Aws/IAM/Client.html#get_account_authorization_details-instance_method).

## Installation

Add this line to your application's Gemfile:

{% highlight ruby %}
gem 'miam'
{% endhighlight %}

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install miam

## Usage

{% highlight sh %}
export AWS_ACCESS_KEY_ID='...'
export AWS_SECRET_ACCESS_KEY='...'
export AWS_REGION='us-east-1'
miam -e -o IAMfile  # export IAM
vi IAMfile
miam -a --dry-run
miam -a             # apply `IAMfile`
{% endhighlight %}

## Help

{% highlight sh %}
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
        --export-concurrency N
        --target REGEXP
        --no-color
        --no-progress
        --debug
{% endhighlight %}

## IAMfile example

{% highlight ruby %}
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
{% endhighlight %}

## Rename

{% highlight ruby %}
require 'other/iamfile'

user "bob2", :path => "/developer/", :renamed_from => "bob" do
  # ...
end

group "Admin2", :path => "/admin/". :renamed_from => "Admin" do
  # ...
end
{% endhighlight %}

## Similar tools
* [Codenize.tools](http://codenize.tools/)
