FROM ruby:2.4.0-slim

# Install app dependencies
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    nodejs \
    git \
    tor \
    parallel

RUN echo 'gem: --no-document' >> ~/.gemrc
ENV APP_HOME /app
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME
ENV BUNDLE_GEMFILE=$APP_HOME/Gemfile \
    BUNDLE_JOBS=4 \
    BUNDLE_PATH=/bundle

COPY Gemfile* $APP_HOME/
RUN bundle install
COPY . $APP_HOME

CMD parallel --linebuffer --ungroup --jobs 2 :::: jobs.txt
