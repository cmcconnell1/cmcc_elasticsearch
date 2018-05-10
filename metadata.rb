name 'td_elasticsearch'
maintainer 'Sysadmin'
maintainer_email 'sysadmin@terradatum.com'
license 'All Rights Reserved'
description 'TD Wrapper for Elasticsearch cookbook'
long_description 'Installs/Configures td_elasticsearch'
version '0.1.55'
chef_version '>= 12.1' if respond_to?(:chef_version)

depends 'aws'
depends 'sysctl'
depends 'patch'
depends 'java', '~> 1.50.0'
depends 'elasticsearch', '4.0.0' # this is currently internal due to beta branch using invalid version numbers
depends 'cron'
