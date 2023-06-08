describe 'Hash#sort_array!' do
  let(:hash) do
    {:users=>
      {"bob"=>
        {:path=>"/developer/",
         :groups=>[],
         :policies=>
          {"S3"=>
            {"Statement"=>
              [{"Action"=>["s3:Put*", "s3:List*", "s3:Get*"],
                "Effect"=>"Allow",
                "Resource"=>"*"}]}},
         :attached_managed_policies=>[
          "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess",
          "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"],
         :login_profile=>{:password_reset_required=>true}}}}
  end

  let(:expected_hash) do
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
         :attached_managed_policies=>[
          "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess",
          "arn:aws:iam::aws:policy/AmazonElastiCacheReadOnlyAccess"],
         :login_profile=>{:password_reset_required=>true}}}}
  end

  subject { hash.sort_array! }

  it { is_expected.to eq expected_hash }

  context 'on trust policy' do
    let(:expected_trust_policy) do
      {
	'Version' => '2012-10-17',
	'Statement' => [
          {
            'Action' => 'sts:AssumeRole',
            'Effect' => 'Allow',
            'Principal' => {
              'AWS' => 'arn:aws:iam::111122223333:role/Role1',
            },
            'Sid' => 'sid1',
          },
          {
            'Effect' => 'Allow',
            'Principal' => {
              'Federated' => 'arn:aws:iam::111122223333:oidc-provider/oidc.eks.ap-northeast-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE',
            },
            'Action' => 'sts:AssumeRoleWithWebIdentity',
            'Condition' => {
              'StringEquals' => {
                'oidc.eks.ap-northeast-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub' => 'system:serviceaccount:default:miam',
                'oidc.eks.ap-northeast-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:aud' => 'sts.amazonaws.com',
              },
            },
          },
        ],
      }
    end

    let(:actual_trust_policy) do
      {
        'Version' => '2012-10-17',
        'Statement' => [
          {
            # Only the order of key-value pairs below are different
            'Sid' => 'sid1',
            'Effect' => 'Allow',
            'Principal' => {
              'AWS' => 'arn:aws:iam::111122223333:role/Role1',
            },
            'Action' => 'sts:AssumeRole',
          },
          {
            'Effect' => 'Allow',
            'Principal' => {
              'Federated' => 'arn:aws:iam::111122223333:oidc-provider/oidc.eks.ap-northeast-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE',
            },
            'Action' => 'sts:AssumeRoleWithWebIdentity',
            'Condition' => {
              'StringEquals' => {
                'oidc.eks.ap-northeast-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub' => 'system:serviceaccount:default:miam',
                'oidc.eks.ap-northeast-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:aud' => 'sts.amazonaws.com',
              },
            },
          },
        ],
      }
    end

    it 'ignores the order of Hash entries' do
      expected_trust_policy.sort_array!
      actual_trust_policy.sort_array!
      expect(expected_trust_policy).to eq(actual_trust_policy)
    end
  end
end
