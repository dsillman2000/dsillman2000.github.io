FROM timbru31/ruby-node:3.3-slim-hydrogen

# Set the working directory
WORKDIR /srv/jekyll

USER root

# Copy the docs/ directory which contains the Jekyll project
COPY docs/ .

RUN apt-get update && apt-get install -y \ 
    build-essential \
    ruby-dev \
    libffi-dev \
    make \
    zlib1g-dev \
    libssl-dev \
    libreadline6-dev \
    libyaml-dev


RUN gem install bundler
# Install the Jekyll plugins
RUN bundle install --verbose

# Install the Node.js packages
RUN npm install

# Build the Jekyll project
RUN jekyll build

# Expose the Jekyll server port
EXPOSE 4000:4000

# Start the Jekyll server
CMD ["jekyll", "serve", "--host", "0.0.0.0"]