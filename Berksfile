# frozen_string_literal: true
source 'https://supermarket.chef.io'

#cookbook "elasticsearch", git: "https://github.com/elastic/cookbook-elasticsearch.git", branch: "4.0.0-beta"
# from metadata.rb in the elasticsearch community cookbook
#version          '4.0.0-beta'
#berks upload fails
# [2018-01-12T10:39:06.736238 #37428] ERROR -- : Ridley::Errors::HTTPBadRequest: {"error":["Invalid cookbook version '4.0.0-beta'."]}
#version          '4.0.0' # try knife upload think chef-client still dies next we just fork and change version

# knife cookbook upload also fails
# $ knife cookbook upload elasticsearch
# ERROR: Chef::Exceptions::InvalidCookbookVersion: '4.0.0-beta' does not match 'x.y.z' or 'x.y'
cookbook "elasticsearch", path: "../elasticsearch"

metadata
