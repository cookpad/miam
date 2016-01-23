describe 'custom managed policy' do
  let(:dsl) do
    <<-RUBY
      managed_policy "my-policy", :path=>"/" do
        {"Version"=>"2012-10-17",
         "Statement"=>
          [{"Effect"=>"Allow", "Action"=>"directconnect:Describe*", "Resource"=>"*"}]}
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
          "arn:aws:iam::#{MIAM_TEST_ACCOUNT_ID}:policy/my-policy"
        )
      end
    RUBY
  end

  let(:expected) do
    {:users=>
      {"mary"=>
        {:path=>"/staff/",
         :groups=>[],
         :attached_managed_policies=>[
          "arn:aws:iam::#{MIAM_TEST_ACCOUNT_ID}:policy/my-policy"],
         :policies=>
          {"S3"=>
            {"Statement"=>
              [{"Action"=>["s3:Get*", "s3:List*"],
                "Effect"=>"Allow",
                "Resource"=>"*"}]}}}},
     :groups=>{},
     :instance_profiles=>{},
     :policies=>
      {"my-policy"=>
        {:path=>"/",
         :document=>
          {"Version"=>"2012-10-17",
           "Statement"=>
            [{"Effect"=>"Allow",
              "Action"=>"directconnect:Describe*",
              "Resource"=>"*"}]}}},
     :roles=>{}}
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

  context 'when create and attach' do
    subject { client }

    it do
      updated = apply(subject) {
        <<-RUBY
          managed_policy "my-policy", :path=>"/" do
            {"Version"=>"2012-10-17",
             "Statement"=>
              [{"Effect"=>"Allow", "Action"=>"directconnect:Describe*", "Resource"=>"*"}]}
          end

          managed_policy "my-policy2", :path=>"/" do
            {"Version"=>"2012-10-17",
             "Statement"=>
              [{"Effect"=>"Deny", "Action"=>"directconnect:Describe*", "Resource"=>"*"}]}
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
              "arn:aws:iam::#{MIAM_TEST_ACCOUNT_ID}:policy/my-policy",
              "arn:aws:iam::#{MIAM_TEST_ACCOUNT_ID}:policy/my-policy2"
            )
          end
        RUBY
      }

      expect(updated).to be_truthy
      expected[:policies]["my-policy2"] = {:path=>"/", :document=>{"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Deny", "Action"=>"directconnect:Describe*", "Resource"=>"*"}]}}
      expected[:users]["mary"][:attached_managed_policies] << "arn:aws:iam::#{MIAM_TEST_ACCOUNT_ID}:policy/my-policy2"
      expected[:users]["mary"][:attached_managed_policies].sort!
      actual = export
      actual[:users]["mary"][:attached_managed_policies].sort!
      expect(actual).to eq expected
    end
  end

  context 'when create and delete' do
    subject { client }

    it do
      updated = apply(subject) {
        <<-RUBY
          managed_policy "my-policy2", :path=>"/" do
            {"Version"=>"2012-10-17",
             "Statement"=>
              [{"Effect"=>"Deny", "Action"=>"directconnect:Describe*", "Resource"=>"*"}]}
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
              "arn:aws:iam::#{MIAM_TEST_ACCOUNT_ID}:policy/my-policy2"
            )
          end
        RUBY
      }

      expect(updated).to be_truthy
      expected[:policies] = {"my-policy2" => {:path=>"/", :document=>{"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Deny", "Action"=>"directconnect:Describe*", "Resource"=>"*"}]}}}
      expected[:users]["mary"][:attached_managed_policies] = ["arn:aws:iam::#{MIAM_TEST_ACCOUNT_ID}:policy/my-policy2"]
      expect(export).to eq expected
    end
  end

  context 'when update' do
    subject { client }

    it do
      updated = apply(subject) {
        <<-RUBY
          managed_policy "my-policy", :path=>"/" do
            {"Version"=>"2012-10-17",
             "Statement"=>
              [{"Effect"=>"Deny", "Action"=>"directconnect:*", "Resource"=>"*"}]}
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
              "arn:aws:iam::#{MIAM_TEST_ACCOUNT_ID}:policy/my-policy"
            )
          end
        RUBY
      }

      expect(updated).to be_truthy
      expected[:policies]["my-policy"] = {:path=>"/", :document=>{"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Deny", "Action"=>"directconnect:*", "Resource"=>"*"}]}}
      expect(export).to eq expected
    end
  end

  context 'when update 7 times' do
    subject { client }

    it do
      4.times do
        apply(subject) { dsl }

        apply(subject) {
          <<-RUBY
            managed_policy "my-policy", :path=>"/" do
              {"Version"=>"2012-10-17",
               "Statement"=>
                [{"Effect"=>"Deny", "Action"=>"directconnect:*", "Resource"=>"*"}]}
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
                "arn:aws:iam::#{MIAM_TEST_ACCOUNT_ID}:policy/my-policy"
              )
            end
          RUBY
        }
      end

      expected[:policies]["my-policy"] = {:path=>"/", :document=>{"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Deny", "Action"=>"directconnect:*", "Resource"=>"*"}]}}
      expect(export).to eq expected
    end
  end
end
