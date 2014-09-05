$jekyll_script = <<SCRIPT
curl -L https://get.rvm.io | bash -s stable --ruby=2.1.1
source /home/vagrant/.rvm/scripts/rvm
gem install bundler
cd /vagrant && bundle install && bundle exec jekyll serve -w --force_polling
SCRIPT

Vagrant.configure(2) do |config|
  config.vm.box = "hashicorp/precise64"
  config.vm.network "forwarded_port", guest: 4000, host: 4000

  config.vm.provision "shell", inline: "apt-get -y install curl nodejs"
  config.vm.provision "shell", inline: $jekyll_script, privileged: false
end