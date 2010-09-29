# for reference.  need to make this more general.
mkdir -p ~/.ssh
chmod 700 ~/.ssh

echo "github.com,207.97.227.239 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" >> ~/.ssh/known_hosts
echo '<%= cookbooks_deploy_key %>' > ~/.ssh/cookbooks_deploy_key
echo '<%= terraform_deploy_key %>' > ~/.ssh/terraform_deploy_key
chmod 600 ~/.ssh/*


eval `ssh-agent`
ssh-add ~/.ssh/terraform_deploy_key
git clone <%= terraform_repository %> ~/terraform
ssh-add -D

pushd ~/terraform
  git submodule init

  ssh-add ~/.ssh/cookbooks_deploy_key
  git submodule update
  ssh-add -D

popd

ssh-agent -k

chef-solo -c ~/terraform/chef/solo.rb -j ~/terraform/chef/node.json

} &> /var/log/terraform

reboot