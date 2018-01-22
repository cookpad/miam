describe 'ignore login profile' do
  let(:dsl) do
    <<-RUBY
      user "bob", :path=>"/developer/" do
        login_profile :password_reset_required=>true

        policy "S3" do
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

  let(:update_dsl) do
    <<-RUBY
      user "bob", :path=>"/developer/" do
        login_profile :password_reset_required=>false

        policy "S3" do
          {"Statement"=>
            [{"Action"=>
               ["s3:Get*",
                "s3:List*",
                "s3:Put*"],
              "Effect"=>"Allow",
              "Resource"=>"*"}]}
        end
      end
    RUBY
  end

  let(:expected) do
    {:users=>
      {"bob"=>
        {:path=>"/developer/",
         :groups=>[],
         :policies=>
          {"S3"=>
            {"Statement"=>
              [{"Action"=>["s3:Get*", "s3:List*", "s3:Put*"],
                "Effect"=>"Allow",
                "Resource"=>"*"}]}},
         :attached_managed_policies=>[],
         :login_profile=>{:password_reset_required=>true}}},
     :groups=>{},
     :policies=>{},
     :roles=>{},
     :instance_profiles=>{}}
  end

  before(:each) do
    apply { dsl }
  end

  context 'when no change' do
    subject { client(ignore_login_profile: true) }

    it do
      updated = apply(subject) { update_dsl }
      expect(updated).to be_truthy
      expect(export).to eq expected
    end
  end
end
