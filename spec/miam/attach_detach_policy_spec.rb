describe 'attach/detach policy' do
  let(:dsl) do
    <<-RUBY
      user "bob", :path=>"/developer/" do
        login_profile :password_reset_required=>true

        groups(
          "Admin",
          "SES"
        )

        policy "S3" do
          {"Statement"=>
            [{"Action"=>
               ["s3:Get*",
                "s3:List*"],
              "Effect"=>"Allow",
              "Resource"=>"*"}]}
        end

        attached_managed_policies(
          "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"
        )
      end

      user "mary", :path=>"/staff/" do
        policy "S3" do
          {"Statement"=>
            [{"Action"=>
               ["s3:Get*",
                "s3:List*"],
              "Effect"=>"Allow",
              "Resource"=>"*"}]}
        end

        attached_managed_policies(
          "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"
        )
      end

      group "Admin", :path=>"/admin/" do
        policy "Admin" do
          {"Statement"=>[{"Effect"=>"Allow", "Action"=>"*", "Resource"=>"*"}]}
        end

        attached_managed_policies(
          "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"
        )
      end

      group "SES", :path=>"/ses/" do
        policy "ses-policy" do
          {"Statement"=>
            [{"Effect"=>"Allow", "Action"=>"ses:SendRawEmail", "Resource"=>"*"}]}
        end

        attached_managed_policies(
          "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"
        )
      end

      role "my-role", :path=>"/any/" do
        instance_profiles(
          "my-instance-profile"
        )

        assume_role_policy_document do
          {"Version"=>"2012-10-17",
           "Statement"=>
            [{"Sid"=>"",
              "Effect"=>"Allow",
              "Principal"=>{"Service"=>"ec2.amazonaws.com"},
              "Action"=>"sts:AssumeRole"}]}
        end

        policy "role-policy" do
          {"Statement"=>
            [{"Action"=>
               ["s3:Get*",
                "s3:List*"],
              "Effect"=>"Allow",
              "Resource"=>"*"}]}
        end

        attached_managed_policies(
          "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"
        )
      end

      instance_profile "my-instance-profile", :path=>"/profile/"
    RUBY
  end

  let(:expected) do
    {:users=>
      {"bob"=>
        {:path=>"/developer/",
         :groups=>["Admin", "SES"],
         :attached_managed_policies=>[
          "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"],
         :policies=>
          {"S3"=>
            {"Statement"=>
              [{"Action"=>["s3:Get*", "s3:List*"],
                "Effect"=>"Allow",
                "Resource"=>"*"}]}},
         :login_profile=>{:password_reset_required=>true}},
       "mary"=>
        {:path=>"/staff/",
         :groups=>[],
         :attached_managed_policies=>[
          "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"],
         :policies=>
          {"S3"=>
            {"Statement"=>
              [{"Action"=>["s3:Get*", "s3:List*"],
                "Effect"=>"Allow",
                "Resource"=>"*"}]}}}},
     :groups=>
      {"Admin"=>
        {:path=>"/admin/",
         :attached_managed_policies=>[
          "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"],
         :policies=>
          {"Admin"=>
            {"Statement"=>[{"Effect"=>"Allow", "Action"=>"*", "Resource"=>"*"}]}}},
       "SES"=>
        {:path=>"/ses/",
         :attached_managed_policies=>[
          "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"],
         :policies=>
          {"ses-policy"=>
            {"Statement"=>
              [{"Effect"=>"Allow",
                "Action"=>"ses:SendRawEmail",
                "Resource"=>"*"}]}}}},
     :policies=>{},
     :roles=>
      {"my-role"=>
        {:path=>"/any/",
         :assume_role_policy_document=>
          {"Version"=>"2012-10-17",
           "Statement"=>
            [{"Sid"=>"",
              "Effect"=>"Allow",
              "Principal"=>{"Service"=>"ec2.amazonaws.com"},
              "Action"=>"sts:AssumeRole"}]},
         :instance_profiles=>["my-instance-profile"],
         :attached_managed_policies=>[
          "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"],
         :policies=>
          {"role-policy"=>
            {"Statement"=>
              [{"Action"=>["s3:Get*", "s3:List*"],
                "Effect"=>"Allow",
                "Resource"=>"*"}]}}}},
     :instance_profiles=>{"my-instance-profile"=>{:path=>"/profile/"}}}
  end

  before(:each) do
    apply { dsl }
  end

  context 'when no change' do
    subject { client }

    it do
      updated = apply(subject) { dsl }
      expect(updated).to be_falsey
      expect(export).to eq expected
    end
  end

  context 'when attach policy' do
    let(:update_policy_dsl) do
      <<-RUBY
        user "bob", :path=>"/developer/" do
          login_profile :password_reset_required=>true

          groups(
            "Admin",
            "SES"
          )

          policy "S3" do
            {"Statement"=>
              [{"Action"=>
                 ["s3:Get*",
                  "s3:List*"],
                "Effect"=>"Allow",
                "Resource"=>"*"}]}
          end

          attached_managed_policies(
            "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"
          )
        end

        user "mary", :path=>"/staff/" do
          policy "S3" do
            {"Statement"=>
              [{"Action"=>
                 ["s3:Get*",
                  "s3:List*"],
                "Effect"=>"Allow",
                "Resource"=>"*"}]}
          end

          attached_managed_policies(
            "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess",
            "arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess"
          )
        end

        group "Admin", :path=>"/admin/" do
          policy "Admin" do
            {"Statement"=>[{"Effect"=>"Allow", "Action"=>"*", "Resource"=>"*"}]}
          end

          attached_managed_policies(
            "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"
          )
        end

        group "SES", :path=>"/ses/" do
          policy "ses-policy" do
            {"Statement"=>
              [{"Effect"=>"Allow", "Action"=>"ses:SendRawEmail", "Resource"=>"*"}]}
          end

          attached_managed_policies(
            "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess",
            "arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess"
          )
        end

        role "my-role", :path=>"/any/" do
          instance_profiles(
            "my-instance-profile"
          )

          assume_role_policy_document do
            {"Version"=>"2012-10-17",
             "Statement"=>
              [{"Sid"=>"",
                "Effect"=>"Allow",
                "Principal"=>{"Service"=>"ec2.amazonaws.com"},
                "Action"=>"sts:AssumeRole"}]}
          end

          policy "role-policy" do
            {"Statement"=>
              [{"Action"=>
                 ["s3:Get*",
                  "s3:List*"],
                "Effect"=>"Allow",
                "Resource"=>"*"}]}
          end

          attached_managed_policies(
            "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess",
            "arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess"
          )
        end

        instance_profile "my-instance-profile", :path=>"/profile/"
      RUBY
    end

    subject { client }

    it do
      updated = apply(subject) { update_policy_dsl }
      expect(updated).to be_truthy
      expected[:users]["mary"][:attached_managed_policies] << "arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess"
      expected[:groups]["SES"][:attached_managed_policies] << "arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess"
      expected[:roles]["my-role"][:attached_managed_policies] << "arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess"
      expect(export).to eq expected
    end
  end

  context 'when detach policy' do
    let(:update_policy_dsl) do
      <<-RUBY
        user "bob", :path=>"/developer/" do
          login_profile :password_reset_required=>true

          groups(
            "Admin",
            "SES"
          )

          policy "S3" do
            {"Statement"=>
              [{"Action"=>
                 ["s3:Get*",
                  "s3:List*"],
                "Effect"=>"Allow",
                "Resource"=>"*"}]}
          end

          attached_managed_policies(
            "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"
          )
        end

        user "mary", :path=>"/staff/" do
          policy "S3" do
            {"Statement"=>
              [{"Action"=>
                 ["s3:Get*",
                  "s3:List*"],
                "Effect"=>"Allow",
                "Resource"=>"*"}]}
          end

          attached_managed_policies(
          )
        end

        group "Admin", :path=>"/admin/" do
          policy "Admin" do
            {"Statement"=>[{"Effect"=>"Allow", "Action"=>"*", "Resource"=>"*"}]}
          end

          attached_managed_policies(
            "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"
          )
        end

        group "SES", :path=>"/ses/" do
          policy "ses-policy" do
            {"Statement"=>
              [{"Effect"=>"Allow", "Action"=>"ses:SendRawEmail", "Resource"=>"*"}]}
          end

          attached_managed_policies(
          )
        end

        role "my-role", :path=>"/any/" do
          instance_profiles(
            "my-instance-profile"
          )

          assume_role_policy_document do
            {"Version"=>"2012-10-17",
             "Statement"=>
              [{"Sid"=>"",
                "Effect"=>"Allow",
                "Principal"=>{"Service"=>"ec2.amazonaws.com"},
                "Action"=>"sts:AssumeRole"}]}
          end

          policy "role-policy" do
            {"Statement"=>
              [{"Action"=>
                 ["s3:Get*",
                  "s3:List*"],
                "Effect"=>"Allow",
                "Resource"=>"*"}]}
          end

          attached_managed_policies(
          )
        end

        instance_profile "my-instance-profile", :path=>"/profile/"
      RUBY
    end

    subject { client }

    it do
      updated = apply(subject) { update_policy_dsl }
      expect(updated).to be_truthy
      expected[:users]["mary"][:attached_managed_policies].clear
      expected[:groups]["SES"][:attached_managed_policies].clear
      expected[:roles]["my-role"][:attached_managed_policies].clear
      expect(export).to eq expected
    end
  end
end
