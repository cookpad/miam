describe 'create' do
  context 'when empty' do
    subject { client }

    it do
      updated = apply(subject) { '' }
      expect(updated).to be_falsey
      expect(export).to eq({:users=>{}, :groups=>{}, :roles=>{}, :instance_profiles=>{}, :policies => {}})
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

        instance_profile "my-instance-profile", :path=>"/profile/"
      RUBY
    end

    context 'when apply' do
      subject { client }

      let(:expected) do
        {:users=>
          {"bob"=>
            {:path=>"/devloper/",
             :groups=>["Admin", "SES"],
             :attached_managed_policies=>[],
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
             :attached_managed_policies=>[],
             :policies=>
              {"S3"=>
                {"Statement"=>
                  [{"Action"=>["s3:Get*", "s3:List*"],
                    "Effect"=>"Allow",
                    "Resource"=>"*"}]}}}},
         :groups=>
          {"Admin"=>
            {:path=>"/admin/",
             :attached_managed_policies=>[],
             :policies=>
              {"Admin"=>
                {"Statement"=>[{"Effect"=>"Allow", "Action"=>"*", "Resource"=>"*"}]}}},
           "SES"=>
            {:path=>"/ses/",
             :attached_managed_policies=>[],
             :policies=>
              {"ses-policy"=>
                {"Statement"=>
                  [{"Effect"=>"Allow",
                    "Action"=>"ses:SendRawEmail",
                    "Resource"=>"*"}]}}}},
         :policies => {},
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
             :attached_managed_policies=>[],
             :policies=>
              {"role-policy"=>
                {"Statement"=>
                  [{"Action"=>["s3:Get*", "s3:List*"],
                    "Effect"=>"Allow",
                    "Resource"=>"*"}]}}}},
         :instance_profiles=>{"my-instance-profile"=>{:path=>"/profile/"}}}
      end

      it do
        updated = apply(subject) { dsl }
        expect(updated).to be_truthy
        expect(export).to eq expected
      end

      context 'when using template' do
        let(:dsl) do
          <<-RUBY
            template "bob" do
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

            template "mary" do
              policy "S3" do
                {"Statement"=>
                  [{"Action"=>
                     ["s3:Get*",
                      "s3:List*"],
                    "Effect"=>"Allow",
                    "Resource"=>"*"}]}
              end
            end

            user "bob", :path=>"/devloper/" do
              include_template context.user_name
            end

            user "mary", :path=>"/staff/" do
              include_template context.user_name
            end

            template "Admin" do
              policy context.policy_name do
                {"Statement"=>[{"Effect"=>"Allow", "Action"=>"*", "Resource"=>"*"}]}
              end
            end

            template "SES" do
              policy context.policy_name do
                {"Statement"=>
                  [{"Effect"=>"Allow", "Action"=>"ses:SendRawEmail", "Resource"=>"*"}]}
              end
            end

            group "Admin", :path=>"/admin/" do
              include_template context.group_name, policy_name: "Admin"
            end

            group "SES", :path=>"/ses/" do
              context.policy_name = "ses-policy"
              include_template context.group_name
            end

            template "my-role" do
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

            role "my-role", :path=>"/any/" do
              include_template context.role_name
            end

            instance_profile "my-instance-profile", :path=>"/profile/"
          RUBY
        end

        it do
          updated = apply(subject) { dsl }
          expect(updated).to be_truthy
          expect(export).to eq expected
        end
      end
    end

    context 'when dry-run' do
      subject { client(dry_run: true) }

      it do
        updated = apply(subject) { dsl }
        expect(updated).to be_falsey
        expect(export).to eq({:users=>{}, :groups=>{}, :roles=>{}, :instance_profiles=>{}, :policies => {}})
      end
    end
  end
end
