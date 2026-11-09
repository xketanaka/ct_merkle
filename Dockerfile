# Development / test environment for ct_merkle.
ARG RUBY_VERSION=3.4
FROM ruby:${RUBY_VERSION}-slim

# Containers run as the host user (see compose.yaml), so HOME and the gem
# directory must be writable by any user.
ENV HOME=/tmp \
    BUNDLE_PATH=/usr/local/bundle

WORKDIR /app

# Install gems in the image. Only the files bundler needs are copied, so the
# layer is rebuilt only when the dependencies change.
COPY Gemfile ct_merkle.gemspec ./
COPY lib/ct_merkle/version.rb lib/ct_merkle/
RUN bundle install --jobs 4 \
 && chmod -R a+rwX /usr/local/bundle

CMD ["bundle", "exec", "rake", "test"]
