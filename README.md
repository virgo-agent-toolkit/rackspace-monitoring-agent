Rackspace Cloud Monitoring Agent
=============================

### Requirements

- Ruby 1.9+
- github-pages gem (includes jekyll & sass)
- Node (github-pages requires javascript runtime)
- Vagrant (optional)

### Without Vagrant

```
bundle install
bundle exec jekyll serve -w
```

### With Vagrant

[Install Vagrant](https://www.vagrantup.com/downloads). `--force_polling` is used to enable auto recompile of jekyll site.

```
vagrant up
vagrant ssh
cd /vagrant
bundle exec jekyll serve -w --force_polling
```