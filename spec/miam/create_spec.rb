describe 'create' do
  context 'when empty' do
    subject { client }

    it do
      updated = apply(subject) { '' }
      expect(updated).to be_falsey
      expect(export).to eq({:users=>{}, :groups=>{}, :roles=>{}, :instance_profiles=>{}})
    end
  end

  context 'when create user and group' do
    let(:dsl) do
      <<-RUBY
        user "bob", :path=>"/devloper/" do
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
        end

        group "Admin", :path=>"/admin/" do
          policy "Admin" do
            {"Statement"=>[{"Effect"=>"Allow", "Action"=>"*", "Resource"=>"*"}]}
          end
        end

        group "SES", :path=>"/ses/" do
          policy "ses-policy" do
            {"Statement"=>
              [{"Effect"=>"Allow", "Action"=>"ses:SendRawEmail", "Resource"=>"*"}]}
          end
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
        end

        instance_profile "my-instance-profile", :path=>"/profile/" do
          policy "instance-profile-policy" do
            {"Statement"=>
              [{"Action"=>
                 ["s3:Get*",
                  "s3:List*"],
                "Effect"=>"Allow",
                "Resource"=>"*"}]}
          end
        end
      RUBY
    end

    context 'when apply' do
      subject { client }

      it do
        updated = apply(subject) { dsl }
        expect(updated).to be_truthy
        expect(export).to eq(
          {:users=>
            {"bob"=>
              {:path=>"/devloper/",
               :groups=>["Admin", "SES"],
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
               :policies=>
                {"S3"=>
                  {"Statement"=>
                    [{"Action"=>["s3:Get*", "s3:List*"],
                      "Effect"=>"Allow",
                      "Resource"=>"*"}]}}}},
           :groups=>
            {"Admin"=>
              {:path=>"/admin/",
               :policies=>
                {"Admin"=>
                  {"Statement"=>[{"Effect"=>"Allow", "Action"=>"*", "Resource"=>"*"}]}}},
             "SES"=>
              {:path=>"/ses/",
               :policies=>
                {"ses-policy"=>
                  {"Statement"=>
                    [{"Effect"=>"Allow",
                      "Action"=>"ses:SendRawEmail",
                      "Resource"=>"*"}]}}}},
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
               :policies=>
                {"role-policy"=>
                  {"Statement"=>
                    [{"Action"=>["s3:Get*", "s3:List*"],
                      "Effect"=>"Allow",
                      "Resource"=>"*"}]}}}},
           :instance_profiles=>{"my-instance-profile"=>{:path=>"/profile/"}}}
        )
      end
    end

    context 'when dry-run' do
      subject { client(dry_run: true) }

      it do
        updated = apply(subject) { dsl }
        expect(updated).to be_falsey
        expect(export).to eq({:users=>{}, :groups=>{}, :roles=>{}, :instance_profiles=>{}})
      end
    end
  end
end
