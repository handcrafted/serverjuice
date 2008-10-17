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
apt-get -y install build-essential wget screen imagemagick

# Install tools for Nginx
apt-get -y install libpcre3-dev libpcre3 openssl libssl-dev nginx

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

# Install other Gems
gem install $RDOC $RI RedCloth tinder json rake tzinfo BlueCloth god thin vlad

# Install Nginx
cd /usr/local/src
wget http://sysoev.ru/nginx/nginx-0.6.32.tar.gz
tar xzvf nginx-0.6.32.tar.gz
# If you want to live on the edge and get the latest nginx-upstream-fair, then use:
git clone git://github.com/gnosek/nginx-upstream-fair.git
cd nginx-0.6.32
./configure --sbin-path=/usr/sbin/nginx --pid-path=/var/run/nginx.pid --lock-path=/var/lock/nginx.lock --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --with-http_ssl_module --add-module=/usr/local/src/nginx-upstream-fair --with-http_stub_status_module
make
make install

# Install Sphinx
cd /usr/local/src/
wget http://www.sphinxsearch.com/downloads/sphinx-0.9.8.tar.gz
tar -zxvf sphinx-0.9.8.tar.gz
cd sphinx-0.9.8
./configure
make
make install

# Install thin
thin install
/usr/sbin/update-rc.d -f thin defaults
    EOF
  end
end
