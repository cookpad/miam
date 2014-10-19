describe 'update' do
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
    RUBY
  end

  let(:expected) do
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
                "Resource"=>"*"}]}}}}}
  end

  before(:each) do
    apply { dsl }
  end

  context 'when rename user' do
    let(:rename_user_dsl) do
      <<-RUBY
        user "bob2", :path=>"/devloper/", :renamed_from=>"bob" do
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
      RUBY
    end

    subject { client }

    it do
      updated = apply(subject) { rename_user_dsl }
      expect(updated).to be_truthy
      expected[:users]["bob2"] = expected[:users].delete("bob")
      expect(export).to eq expected
    end
  end

  context 'when rename group' do
    let(:rename_group_dsl) do
      <<-RUBY
        user "bob", :path=>"/devloper/" do
          login_profile :password_reset_required=>true

          groups(
            "Admin",
            "SES2"
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

        group "SES2", :path=>"/ses/", :renamed_from=>"SES2" do
          policy "ses-policy" do
            {"Statement"=>
              [{"Effect"=>"Allow", "Action"=>"ses:SendRawEmail", "Resource"=>"*"}]}
          end
        end
      RUBY
    end

    subject { client }

    it do
      updated = apply(subject) { rename_group_dsl }
      expect(updated).to be_truthy
      expected[:users]["bob"][:groups] = ["Admin", "SES2"]
      expected[:groups]["SES2"] = expected[:groups].delete("SES")
      expect(export).to eq expected
    end
  end

  context 'when rename without renamed_from' do
    let(:rename_without_renamed_from_dsl) do
      <<-RUBY
        user "bob2", :path=>"/devloper/" do
          login_profile :password_reset_required=>true

          groups(
            "Admin",
            "SES2"
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

        group "SES2", :path=>"/ses/" do
          policy "ses-policy" do
            {"Statement"=>
              [{"Effect"=>"Allow", "Action"=>"ses:SendRawEmail", "Resource"=>"*"}]}
          end
        end
      RUBY
    end

    subject { client }

    it do
      updated = apply(subject) { rename_without_renamed_from_dsl }
      expect(updated).to be_truthy
      expected[:users]["bob"][:groups] = ["Admin", "SES2"]
      expected[:users]["bob2"] = expected[:users].delete("bob")
      expected[:groups]["SES2"] = expected[:groups].delete("SES")
      expect(export).to eq expected
    end
  end
end
