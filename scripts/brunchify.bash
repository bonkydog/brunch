#########################################################
# packages

# enable all repositories
sed -i 's/^#deb/deb/' /etc/apt/sources.list
sed -i 's/universe/universe multiverse/' /etc/apt/sources.list

# update packages
aptitude update
aptitude -y full-upgrade

# install packages for system administration
aptitude -y install \
  ruby \
  ruby1.8-dev \
  libopenssl-ruby1.8 \
  libshadow-ruby1.8 \
  libxml2-dev \
  libxslt-dev \
  rdoc1.8 \
  ri1.8 \
  irb1.8 \
  build-essential \
  wget \
  curl \
  ssl-cert \
  vim \
  less \
  git-core


#########################################################
# ruby gems

wget http://production.cf.rubygems.org/rubygems/rubygems-1.3.7.tgz
tar zxvf rubygems-1.3.7.tgz

pushd rubygems-1.3.7
  ruby ./setup.rb
  ln -sfv /usr/bin/gem1.8 /usr/bin/gem
popd

rm -rf rubygems-1.3.7*

gem update --system

gem install --no-rdoc --no-ri bundler

#########################################################
# chef

gem install --no-rdoc --no-ri chef

#########################################################
# finish

sudo init 1
touch ~ubuntu/.brunch_done
reboot
