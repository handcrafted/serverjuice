class ServerJuice
  attr_reader :script_name, :server, :hostname

  def initialize(script_name, server, hostname)
    @script_name = script_name
    @server = server
    @hostname = hostname
  end

  def remote_tmp_file
    "#{script_name}.tmp"
  end

  def remote_script_name
    "#{script_name}.sh"
  end

  # Create a script on the remote server that will configure it, and run it
  def deploy
    system %Q[ssh -lroot "#{server}" <<'EOF'
 	cat >"#{remote_script_name}" <<'EOS'
#{generate}EOS
chmod +x "#{remote_script_name}"
source "#{remote_script_name}"
EOF
    ]
  end

  def generate
    <<-EOF
# #{remote_script_name}:
#
# Set up a clean Ubuntu 8.04 install for Rails production deployment.
#
# Tested on:
#
# linode.com - Ubuntu 8.04 LTS
#
# More info:
#
# http://github.com/sansdev/serverjuice
#

# Configure your desired options here
DESIRED_HOSTNAME="#{hostname}"
RI="--no-ri"                         # Comment to install ri
RDOC="--no-rdoc"                     # Comment to install RDOC

# Ensure hostname is configured
if [ -z "$DESIRED_HOSTNAME" ]; then
	echo DESIRED_HOSTNAME must be set.
	exit 1
fi

# Set hostname
echo "$DESIRED_HOSTNAME" >/etc/hostname
sed -re "s/^(127.0.1.1[[:space:]]+).*/\\1$DESIRED_HOSTNAME/" </etc/hosts >"#{remote_tmp_file}" && cp -f "#{remote_tmp_file}" /etc/hosts && rm -f "#{remote_tmp_file}"
/etc/init.d/hostname.sh start

# Upgrade system packages
apt-get -y update
apt-get -y upgrade

# Install essential tools
apt-get -y install build-essential wget

# Install Apache 2
apt-get -y install apache2 apache2-prefork-dev

# Install MySQL Server
apt-get -y install mysql-server mysql-client libmysqlclient15-dev

# Install Git
apt-get -y install git-core

# Install Core Ruby
apt-get -y install ruby-full

# Install RubyGems
(
RUBYGEMS=rubygems-1.3.0 &&
cd /usr/local/src &&
rm -rf $RUBYGEMS $RUBYGEMS.tgz &&
# Note: Filename in URL does not determine which file to download
wget http://rubyforge.org/frs/download.php/43985/rubygems-1.3.0.tgz &&
tar -xzf $RUBYGEMS.tgz &&
cd $RUBYGEMS &&
ruby setup.rb $RDOC $RI &&
ln -sf /usr/bin/gem1.8 /usr/bin/gem &&
cd .. &&
rm -rf $RUBYGEMS $RUBYGEMS.tgz
)

# Install Rails
gem install $RDOC $RI rails

# Install MySQL Ruby driver
gem install $RDOC $RI mysql

# Install and setup Passenger
gem install $RDOC $RI passenger
(echo; echo) | passenger-install-apache2-module
cat >/etc/apache2/conf.d/passenger <<EOP
LoadModule passenger_module /usr/lib/ruby/gems/1.8/gems/passenger-2.0.3/ext/apache2/mod_passenger.so
PassengerRoot /usr/lib/ruby/gems/1.8/gems/passenger-2.0.3
PassengerRuby /usr/bin/ruby1.8
EOP
apache2ctl graceful
    EOF
  end
end
